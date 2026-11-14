/* SPDX-License-Identifier: MIT
 * Pure presentation mathematics. No engine nodes, simulation state, RNG, or I/O.
 * Godot float_64 ABI: 32-bit real_t, 64-bit pointers and GDScript Float.
 */
#include "gdextension_interface.h"
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>

#if defined(_WIN32)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif
typedef struct { float x,y; } V2;
typedef struct { int32_t x,y; } V2i;
typedef struct { V2 p,s; } Rect;
typedef struct { uint64_t opaque; } StringName;
typedef struct { double start,end,duration; V2 home,finish,offset,size; float outer_width; int eligible; } Record;
typedef struct { V2 position; double penalty; Rect rects[6]; int offset_index; } Candidate;
typedef struct { Record *records; size_t *eligible; Candidate *candidates; Rect *samples; uint8_t *active; size_t record_cap,candidate_cap,cached_records,slice_count; int owned_valid; int64_t owned_generation; double cache_clock,cache_delay,times[78]; size_t counts[78]; } Solver;

static GDExtensionClassLibraryPtr library;
static GDExtensionInterfaceStringNameNewWithLatin1Chars name_new;
static GDExtensionPtrDestructor name_destroy;
static GDExtensionPtrDestructor string_destroy;
static GDExtensionInterfaceStringNewWithUtf8Chars string_new;
static GDExtensionInterfaceClassdbConstructObject construct_object;
static GDExtensionInterfaceObjectSetInstance set_instance;
static GDExtensionInterfaceClassdbRegisterExtensionClass2 register_class;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceArrayOperatorIndexConst array_at;
static GDExtensionInterfaceVariantGetType variant_type;
static GDExtensionVariantGetInternalPtrFunc get_array,get_v2,get_rect,get_float,get_int;
static GDExtensionVariantFromTypeConstructorFunc from_v2i;
static GDExtensionPtrBuiltInMethod array_size_method;
static StringName class_name,parent_name;

static int64_t array_size(const void *array) {
    int64_t n=0; array_size_method((void *)array,NULL,&n,0); return n;
}
static void *element(const void *array,int64_t i) { return array_at(array,i); }
static double number(const void *array,int64_t i) { return *(double *)get_float(element(array,i)); }
static V2 vector(const void *array,int64_t i) { return *(V2 *)get_v2(element(array,i)); }
static void *nested(const void *array,int64_t i) { return get_array(element(array,i)); }

/* Separate float operations match Vector2::lerp/add and Rect2::grow/intersection.
 * Build with -fno-fast-math -ffp-contract=off; merging multiply/add changes pixels. */
static float lerp32(float a,float b,float weight) {
    float difference=b-a; float product=difference*weight; return a+product;
}
static Rect sample_rect(const Record *r,double at) {
    double progress=(at-r->start)/r->duration;
    if (progress<0.0) progress=0.0;
    if (progress>1.0) progress=1.0;
    float weight=(float)(1.0-pow(1.0-progress,3.0));
    Rect rect;
    rect.p.x=lerp32(r->home.x,r->finish.x,weight)+r->offset.x;
    rect.p.y=lerp32(r->home.y,r->finish.y,weight)+r->offset.y;
    rect.p.x-=3.0f; rect.p.y-=3.0f;
    rect.s.x=r->size.x+6.0f; rect.s.y=r->size.y+6.0f;
    return rect;
}
static double intersection_area(Rect a,Rect b) {
    float ae_x=a.p.x+a.s.x, ae_y=a.p.y+a.s.y;
    float be_x=b.p.x+b.s.x, be_y=b.p.y+b.s.y;
    if (a.p.x>=be_x || ae_x<=b.p.x || a.p.y>=be_y || ae_y<=b.p.y) return 0.0;
    float x=a.p.x>b.p.x?a.p.x:b.p.x, y=a.p.y>b.p.y?a.p.y:b.p.y;
    float w=(ae_x<be_x?ae_x:be_x)-x, h=(ae_y<be_y?ae_y:be_y)-y;
    float area=w*h;
    return (w>0.0f && h>0.0f)?(double)area:0.0;
}
static int reserve(Solver *self,size_t nr,size_t nc) {
    if(nr>self->record_cap || self->record_cap==0) {
        size_t capacity=nr*2+32;
        Record *records=malloc(capacity*sizeof(Record));
        size_t *eligible=malloc(capacity*sizeof(size_t));
        Rect *samples=malloc(capacity*78*sizeof(Rect));
        uint8_t *active=malloc(capacity*78);
        if(!records || !eligible || !samples || !active) { free(records);free(eligible);free(samples);free(active);return 0; }
        free(self->records);free(self->eligible);free(self->samples);free(self->active);
        self->records=records;self->eligible=eligible;self->samples=samples;self->active=active;self->record_cap=capacity;self->slice_count=0;self->cached_records=0;
    }
    if(nc>self->candidate_cap) {
        Candidate *candidates=malloc((nc*2+16)*sizeof(Candidate));
        if(!candidates)return 0;
        free(self->candidates);self->candidates=candidates;self->candidate_cap=nc*2+16;
    }
    return 1;
}
static V2i solve(Solver *self,const void *records,V2 home,V2 size,V2 viewport,double clock,double duration,double rise,double base_delay,double ink_width,int owned,int64_t generation) {
    int64_t nr=array_size(records),nc=11;
    V2i result={-1,-1};
    if(nr<0 || nc<=0 || !reserve(self,(size_t)nr,(size_t)nc))return result;
    int invalidate=clock!=self->cache_clock || base_delay!=self->cache_delay || (size_t)nr<self->cached_records;
    int reuse=owned && self->owned_valid && generation==self->owned_generation && (size_t)nr>=self->cached_records;
    size_t eligible_count=0;
    for(int64_t i=0;i<nr;i++) {
        Record *r=&self->records[i];
        if(!reuse || (size_t)i>=self->cached_records) {
        if(variant_type(element(records,i))!=GDEXTENSION_VARIANT_TYPE_ARRAY)return result;
        void *a=nested(records,i);
        if(array_size(a)<8)return result;
        const GDExtensionVariantType fields[8]={GDEXTENSION_VARIANT_TYPE_FLOAT,GDEXTENSION_VARIANT_TYPE_FLOAT,GDEXTENSION_VARIANT_TYPE_VECTOR2,GDEXTENSION_VARIANT_TYPE_VECTOR2,GDEXTENSION_VARIANT_TYPE_FLOAT,GDEXTENSION_VARIANT_TYPE_VECTOR2,GDEXTENSION_VARIANT_TYPE_VECTOR2,GDEXTENSION_VARIANT_TYPE_FLOAT};
        for(int f=0;f<8;f++)if(variant_type(element(a,f))!=fields[f])return result;
        Record previous={0};if((size_t)i<self->cached_records)previous=self->records[i];
        r->start=number(a,0);r->end=number(a,1);r->home=vector(a,2);r->finish=vector(a,3);
        r->duration=number(a,4);r->offset=vector(a,5);r->size=vector(a,6);r->outer_width=(float)number(a,7);
        if((size_t)i<self->cached_records && (previous.start!=r->start || previous.end!=r->end || previous.duration!=r->duration || memcmp(&previous.home,&r->home,sizeof(V2)*4)!=0 || previous.outer_width!=r->outer_width))invalidate=1;
        }
        /* Scalar Vector2 components are promoted to GDScript doubles. */
        double dx=(double)r->home.x-home.x,dy=(double)r->home.y-home.y;
        r->eligible=fabs((double)dx)<fmax((double)size.x,(double)r->outer_width)+165.0 && fabs((double)dy)<220.0;
        if(r->eligible)self->eligible[eligible_count++]=(size_t)i;
    }
    if(invalidate)self->slice_count=0;
    self->owned_valid=owned;self->owned_generation=generation;
    self->cache_clock=clock;self->cache_delay=base_delay;self->cached_records=(size_t)nr;
    const V2 positions[11]={{0,0},{0,-52},{0,52},{-70,0},{70,0},{-48,-52},{48,-52},{-48,52},{48,52},{0,-78},{0,78}};
    double top=fmax(112.0,(double)viewport.y*.14);
    double bottom=(double)viewport.y-fmax(112.0,(double)viewport.y*.16)-(double)size.y;
    double width=ink_width<=0.0?(double)size.x:ink_width;
    int any_eligible=eligible_count>0;
    nc=0;
    const double sample_offsets[6]={0.0,.10,.20,.30,.40,.50};
    for(int i=0;i<11;i++) {
        V2 offset=positions[i],pos={home.x+offset.x,home.y+offset.y};
        pos.x=(float)fmin(fmax((double)pos.x,8.0),(double)viewport.x-(double)size.x-8.0);
        pos.y=(float)fmin(fmax((double)pos.y,top),bottom);
        float dx=pos.x-home.x,dy=pos.y-home.y;
        float distance=sqrtf(dx*dx+dy*dy);
        if((double)distance>80.01)continue;
        Candidate *candidate=&self->candidates[nc++];candidate->position=pos;candidate->offset_index=i;
        candidate->penalty=(double)sqrtf(offset.x*offset.x+offset.y*offset.y)*.02;
        V2 finish={pos.x,(float)fmax(top,(double)pos.y-rise)};
        V2 ink_offset={(float)(((double)size.x-width)*.5),0.0f};
        for(int k=0;k<6;k++) {
            double progress=fmin(fmax(sample_offsets[k]/duration,0.0),1.0);
            float weight=(float)(1.0-pow(1.0-progress,3.0));
            Rect *rect=&candidate->rects[k];
            rect->p.x=lerp32(pos.x,finish.x,weight)+ink_offset.x;rect->p.y=lerp32(pos.y,finish.y,weight);
            rect->p.x-=3.0f;rect->p.y-=3.0f;rect->s.x=(float)width+6.0f;rect->s.y=size.y+6.0f;
        }
        if(!any_eligible)break;
    }
    const double offsets[6]={0.0,.10,.20,.30,.40,.50};
    double best=INFINITY;
    for(int step=0;step<13;step++) {
        double delay=base_delay+(double)step*.10;
        Rect *step_rects[6];uint8_t *step_active[6];
        for(int k=0;k<6;k++) {
            double at=clock+delay+offsets[k];size_t slot=0;
            while(slot<self->slice_count && self->times[slot]!=at)slot++;
            if(slot==self->slice_count) {if(slot>=78)return result;self->times[slot]=at;self->counts[slot]=0;self->slice_count++;}
            Rect *rects=self->samples+slot*self->record_cap;uint8_t *active=self->active+slot*self->record_cap;
            for(size_t i=self->counts[slot];i<(size_t)nr;i++) {
                Record *r=&self->records[i];active[i]=at>=r->start && at<r->end;
                if(active[i])rects[i]=sample_rect(r,at);
            }
            self->counts[slot]=(size_t)nr;step_rects[k]=rects;step_active[k]=active;
        }
        for(int64_t c=0;c<nc;c++) {
            Candidate *candidate=&self->candidates[c];double overlap=0.0;int pruned=0;
            for(int k=0;k<6 && !pruned;k++) {
                for(size_t e=0;e<eligible_count;e++) {
                    size_t i=self->eligible[e];
                    if(!step_active[k][i])continue;
                    double area=intersection_area(candidate->rects[k],step_rects[k][i]);
                    if(area>0.0) {
                        overlap+=area;
                        if(overlap>.001 && overlap+candidate->penalty+delay*.1>=best) {pruned=1;break;}
                    }
                }
            }
            if(pruned)continue;
            double score=overlap+candidate->penalty+delay*.1;
            if(score<best) {best=score;result.x=candidate->offset_index;result.y=step;}
            if(overlap<=.001)return result;
        }
    }
    return result;
}
static void score_call(void *userdata,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr *args,GDExtensionInt count,GDExtensionVariantPtr ret,GDExtensionCallError *error) {
    int owned=(int)(uintptr_t)userdata;int arguments=owned?10:9;V2i result={-1,-1};
    if(count!=arguments) {error->error=count<arguments?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=arguments;from_v2i(ret,&result);return;}
    for(int i=0;i<9;i++) {
        GDExtensionVariantType expected=i==0?GDEXTENSION_VARIANT_TYPE_ARRAY:i<4?GDEXTENSION_VARIANT_TYPE_VECTOR2:GDEXTENSION_VARIANT_TYPE_FLOAT;
        if(variant_type(args[i])!=expected) {error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;error->argument=i;error->expected=expected;from_v2i(ret,&result);return;}
    }
    int64_t generation=0;
    if(owned) {if(variant_type(args[9])!=GDEXTENSION_VARIANT_TYPE_INT) {error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;error->argument=9;error->expected=GDEXTENSION_VARIANT_TYPE_INT;from_v2i(ret,&result);return;}generation=*(int64_t *)get_int((void *)args[9]);}
    result=solve(instance,get_array((void *)args[0]),*(V2 *)get_v2((void *)args[1]),*(V2 *)get_v2((void *)args[2]),*(V2 *)get_v2((void *)args[3]),*(double *)get_float((void *)args[4]),*(double *)get_float((void *)args[5]),*(double *)get_float((void *)args[6]),*(double *)get_float((void *)args[7]),*(double *)get_float((void *)args[8]),owned,generation);
    error->error=GDEXTENSION_CALL_OK;from_v2i(ret,&result);
}
static GDExtensionObjectPtr create_solver(void *userdata) {
    (void)userdata;GDExtensionObjectPtr object=construct_object(&parent_name);
    Solver *self=calloc(1,sizeof(Solver));set_instance(object,&class_name,self);return object;
}
static void free_solver(void *userdata,GDExtensionClassInstancePtr instance) {
    (void)userdata;Solver *self=instance;if(!self)return;
    free(self->records);free(self->eligible);free(self->candidates);free(self->samples);free(self->active);free(self);
}
static void initialize(void *userdata,GDExtensionInitializationLevel level) {
    (void)userdata;if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
    name_new(&class_name,"RoundCardFeedbackMath",0);name_new(&parent_name,"RefCounted",0);
    GDExtensionClassCreationInfo2 info={0};info.is_exposed=1;info.create_instance_func=create_solver;info.free_instance_func=free_solver;
    register_class(library,&class_name,&parent_name,&info);
    StringName method,empty;name_new(&method,"score",0);name_new(&empty,"",0);
    uint64_t empty_string=0;string_new(&empty_string,"");
    GDExtensionPropertyInfo returned={0};returned.type=GDEXTENSION_VARIANT_TYPE_VECTOR2I;returned.name=&empty;returned.class_name=&empty;returned.hint_string=&empty_string;
    GDExtensionPropertyInfo parameters[10]={{0}};
    GDExtensionClassMethodArgumentMetadata metadata[10]={0};
    for(int i=0;i<9;i++) {parameters[i].type=i==0?GDEXTENSION_VARIANT_TYPE_ARRAY:i<4?GDEXTENSION_VARIANT_TYPE_VECTOR2:GDEXTENSION_VARIANT_TYPE_FLOAT;parameters[i].name=&empty;parameters[i].class_name=&empty;parameters[i].hint_string=&empty_string;}
    GDExtensionClassMethodInfo method_info={0};method_info.name=&method;method_info.call_func=score_call;method_info.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;method_info.has_return_value=1;method_info.return_value_info=&returned;method_info.argument_count=9;method_info.arguments_info=parameters;method_info.arguments_metadata=metadata;
    register_method(library,&class_name,&method_info);name_destroy(&method);
    name_new(&method,"score_owned",0);parameters[9].type=GDEXTENSION_VARIANT_TYPE_INT;parameters[9].name=&empty;parameters[9].class_name=&empty;parameters[9].hint_string=&empty_string;
    method_info.argument_count=10;method_info.method_userdata=(void *)(uintptr_t)1;register_method(library,&class_name,&method_info);
    name_destroy(&method);name_destroy(&empty);string_destroy(&empty_string);
}
static void deinitialize(void *userdata,GDExtensionInitializationLevel level) {
    (void)userdata;if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
    unregister_class(library,&class_name);name_destroy(&class_name);name_destroy(&parent_name);
}
EXPORT GDExtensionBool roundcard_feedback_init(GDExtensionInterfaceGetProcAddress get,GDExtensionClassLibraryPtr lib,GDExtensionInitialization *init) {
    library=lib;
#define LOAD(variable,type,key) variable=(type)get(key)
    LOAD(name_new,GDExtensionInterfaceStringNameNewWithLatin1Chars,"string_name_new_with_latin1_chars");
    LOAD(construct_object,GDExtensionInterfaceClassdbConstructObject,"classdb_construct_object");
    LOAD(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance");
    LOAD(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass2,"classdb_register_extension_class2");
    LOAD(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");
    LOAD(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");
    LOAD(array_at,GDExtensionInterfaceArrayOperatorIndexConst,"array_operator_index_const");
    LOAD(variant_type,GDExtensionInterfaceVariantGetType,"variant_get_type");
    GDExtensionInterfaceVariantGetPtrDestructor destructor=(GDExtensionInterfaceVariantGetPtrDestructor)get("variant_get_ptr_destructor");name_destroy=destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);string_destroy=destructor(GDEXTENSION_VARIANT_TYPE_STRING);
    LOAD(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");
    GDExtensionInterfaceGetVariantGetInternalPtrFunc internal=(GDExtensionInterfaceGetVariantGetInternalPtrFunc)get("variant_get_ptr_internal_getter");
    get_array=internal(GDEXTENSION_VARIANT_TYPE_ARRAY);get_v2=internal(GDEXTENSION_VARIANT_TYPE_VECTOR2);get_rect=internal(GDEXTENSION_VARIANT_TYPE_RECT2);get_float=internal(GDEXTENSION_VARIANT_TYPE_FLOAT);get_int=internal(GDEXTENSION_VARIANT_TYPE_INT);
    GDExtensionInterfaceGetVariantFromTypeConstructor from=(GDExtensionInterfaceGetVariantFromTypeConstructor)get("get_variant_from_type_constructor");from_v2i=from(GDEXTENSION_VARIANT_TYPE_VECTOR2I);
    GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin=(GDExtensionInterfaceVariantGetPtrBuiltinMethod)get("variant_get_ptr_builtin_method");StringName size_name;name_new(&size_name,"size",0);array_size_method=builtin(GDEXTENSION_VARIANT_TYPE_ARRAY,&size_name,3173160232);name_destroy(&size_name);
    init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=NULL;init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;
    return 1;
}

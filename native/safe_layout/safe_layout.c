/* SPDX-License-Identifier: MIT
 * Stateless presentation-only rectangle/time query. No nodes, renderer, simulation, RNG,
 * persistent cache or production integration. Godot standard float_64 ABI.
 */
#include "gdextension_interface.h"
#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#if defined(_WIN32)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif
typedef struct { float x,y; } V2;
typedef struct { V2 position,size; } Rect;
typedef struct { int32_t x,y; } V2i;
typedef struct { uint64_t opaque; } Name;
typedef struct { Rect rect; double start,end; } Peer;
static GDExtensionClassLibraryPtr library;
static GDExtensionInterfaceStringNameNewWithLatin1Chars name_new;
static GDExtensionInterfaceStringNewWithUtf8Chars string_new;
static GDExtensionPtrDestructor name_free,string_free;
static GDExtensionInterfaceClassdbConstructObject construct_object;
static GDExtensionInterfaceObjectSetInstance set_instance;
static GDExtensionInterfaceClassdbRegisterExtensionClass2 register_class;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceArrayOperatorIndexConst array_at;
static GDExtensionInterfaceVariantGetType variant_type;
static GDExtensionVariantGetInternalPtrFunc raw_array,raw_rect,raw_float,raw_delays,raw_int;
static GDExtensionVariantFromTypeConstructorFunc from_v2i;
static GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst delay_at;
static GDExtensionPtrBuiltInMethod array_size,delays_size;
static Name class_name,parent_name;
static int64_t size_of(GDExtensionPtrBuiltInMethod method,void *value){
    int64_t result=0;method(value,NULL,&result,0);return result;
}
static int valid_rect(Rect r){
    return isfinite(r.position.x)&&isfinite(r.position.y)&&isfinite(r.size.x)&&isfinite(r.size.y)&&
        r.size.x>=0.0f&&r.size.y>=0.0f&&isfinite(r.position.x+r.size.x)&&isfinite(r.position.y+r.size.y);
}
static int intersects(Rect a,Rect b){
    /* Separate float32 end additions reproduce Rect2::intersects(false).
     * Merely touching horizontal/vertical edges never counts as overlap. */
    float ax=a.position.x+a.size.x,ay=a.position.y+a.size.y;
    float bx=b.position.x+b.size.x,by=b.position.y+b.size.y;
    return !(a.position.x>=bx || ax<=b.position.x || a.position.y>=by || ay<=b.position.y);
}
static V2i find_first(void *candidate_array,void *peer_array,void *delay_array,double clock,double duration){
    V2i invalid={-2,-2},none={-1,-1};
    int64_t nc=size_of(array_size,candidate_array),np=size_of(array_size,peer_array),nd=size_of(delays_size,delay_array);
    if(nc<0||np<0||nd<0||nc>INT32_MAX||nd>INT32_MAX||!isfinite(clock)||!isfinite(duration)||duration<0.0||
       (uint64_t)nc>SIZE_MAX/sizeof(Rect)||(uint64_t)np>SIZE_MAX/sizeof(Peer))return invalid;
    Rect *candidates=nc?malloc((size_t)nc*sizeof(Rect)):NULL;
    Peer *peers=np?malloc((size_t)np*sizeof(Peer)):NULL;
    if((nc&&!candidates)||(np&&!peers)){free(candidates);free(peers);return invalid;}
    const double *delays=nd?delay_at(delay_array,0):NULL;
    /* Decode/validate the complete input before searching, including peers
     * occurring after an otherwise early successful candidate. No peer cap. */
    for(int64_t c=0;c<nc;c++){
        GDExtensionVariantPtr v=array_at(candidate_array,c);
        if(variant_type(v)!=GDEXTENSION_VARIANT_TYPE_RECT2)goto bad;
        candidates[c]=*(Rect *)raw_rect(v);
        if(!valid_rect(candidates[c]))goto bad;
    }
    for(int64_t p=0;p<np;p++){
        GDExtensionVariantPtr value=array_at(peer_array,p);
        if(variant_type(value)!=GDEXTENSION_VARIANT_TYPE_ARRAY)goto bad;
        void *row=raw_array(value);
        if(size_of(array_size,row)!=3)goto bad;
        GDExtensionVariantPtr r=array_at(row,0),s=array_at(row,1),e=array_at(row,2);
        if(variant_type(r)!=GDEXTENSION_VARIANT_TYPE_RECT2||variant_type(s)!=GDEXTENSION_VARIANT_TYPE_FLOAT||variant_type(e)!=GDEXTENSION_VARIANT_TYPE_FLOAT)goto bad;
        peers[p]=(Peer){*(Rect *)raw_rect(r),*(double *)raw_float(s),*(double *)raw_float(e)};
        if(!valid_rect(peers[p].rect)||!isfinite(peers[p].start)||!isfinite(peers[p].end)||peers[p].end<peers[p].start)goto bad;
    }
    for(int64_t d=0;d<nd;d++)if(!isfinite(delays[d])||!isfinite(clock+delays[d])||!isfinite(clock+delays[d]+duration+.05))goto bad;
    /* Delay-major, candidate-minor: preserves the supplied lattice/order.
     * Temporal strictness is identical to GDScript's original .05 boundary. */
    for(int64_t d=0;d<nd;d++){
        double start=clock+delays[d],end=start+duration;
        for(int64_t c=0;c<nc;c++){
            int occupied=0;
            for(int64_t p=0;p<np;p++){
                if(!intersects(candidates[c],peers[p].rect))continue;
                if(end+.05<peers[p].start || start>peers[p].end+.05)continue;
                occupied=1;break;
            }
            if(!occupied){V2i result={(int32_t)c,(int32_t)d};free(candidates);free(peers);return result;}
        }
    }
    free(candidates);free(peers);return none;
bad:
    free(candidates);free(peers);return invalid;
}
static void query_call(void *unused,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr *args,GDExtensionInt count,GDExtensionVariantPtr ret,GDExtensionCallError *error){
    (void)unused;(void)instance;V2i result={-2,-2};
    const GDExtensionVariantType types[5]={GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,GDEXTENSION_VARIANT_TYPE_FLOAT,GDEXTENSION_VARIANT_TYPE_FLOAT};
    if(count!=5){error->error=count<5?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=5;from_v2i(ret,&result);return;}
    for(int i=0;i<5;i++)if(variant_type(args[i])!=types[i]){error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;error->argument=i;error->expected=types[i];from_v2i(ret,&result);return;}
    result=find_first(raw_array((void *)args[0]),raw_array((void *)args[1]),raw_delays((void *)args[2]),*(double *)raw_float((void *)args[3]),*(double *)raw_float((void *)args[4]));
    error->error=GDEXTENSION_CALL_OK;from_v2i(ret,&result);
}
static V2i find_first_indexed(void *candidate_array,void *peer_array,void *delay_array,double clock,double duration,int64_t exclude){
    V2i invalid={-2,-2},none={-1,-1};
    int64_t nc=size_of(array_size,candidate_array),np=size_of(array_size,peer_array),nd=size_of(delays_size,delay_array);
    if(nc<0||np<0||nd<0||nc>INT32_MAX||nd>INT32_MAX||exclude < -1||exclude>=np||!isfinite(clock)||!isfinite(duration)||duration<0.0||
       (uint64_t)nc>SIZE_MAX/sizeof(Rect)||(uint64_t)np>SIZE_MAX/sizeof(Peer))return invalid;
    Rect *candidates=nc?malloc((size_t)nc*sizeof(Rect)):NULL;
    Peer *peers=np?malloc((size_t)np*sizeof(Peer)):NULL;
    if((nc&&!candidates)||(np&&!peers)){free(candidates);free(peers);return invalid;}
    const double *delays=nd?delay_at(delay_array,0):NULL;
    /* Validation still covers excluded/empty rows. Only occupancy skips them. */
    for(int64_t c=0;c<nc;c++){
        GDExtensionVariantPtr v=array_at(candidate_array,c);
        if(variant_type(v)!=GDEXTENSION_VARIANT_TYPE_RECT2)goto bad;
        candidates[c]=*(Rect *)raw_rect(v);
        if(!valid_rect(candidates[c]))goto bad;
    }
    for(int64_t p=0;p<np;p++){
        GDExtensionVariantPtr value=array_at(peer_array,p);
        if(variant_type(value)!=GDEXTENSION_VARIANT_TYPE_ARRAY)goto bad;
        void *row=raw_array(value);
        if(size_of(array_size,row)!=3)goto bad;
        GDExtensionVariantPtr r=array_at(row,0),s=array_at(row,1),e=array_at(row,2);
        if(variant_type(r)!=GDEXTENSION_VARIANT_TYPE_RECT2||variant_type(s)!=GDEXTENSION_VARIANT_TYPE_FLOAT||variant_type(e)!=GDEXTENSION_VARIANT_TYPE_FLOAT)goto bad;
        peers[p]=(Peer){*(Rect *)raw_rect(r),*(double *)raw_float(s),*(double *)raw_float(e)};
        if(!valid_rect(peers[p].rect)||!isfinite(peers[p].start)||!isfinite(peers[p].end)||peers[p].end<peers[p].start)goto bad;
    }
    for(int64_t d=0;d<nd;d++)if(!isfinite(delays[d])||!isfinite(clock+delays[d])||!isfinite(clock+delays[d]+duration+.05))goto bad;
    for(int64_t d=0;d<nd;d++){
        double start=clock+delays[d],end=start+duration;
        for(int64_t c=0;c<nc;c++){
            int occupied=0;
            for(int64_t p=0;p<np;p++){
                if(p==exclude||peers[p].rect.size.x<=0.0f||peers[p].rect.size.y<=0.0f)continue;
                if(!intersects(candidates[c],peers[p].rect))continue;
                if(end+.05<peers[p].start || start>peers[p].end+.05)continue;
                occupied=1;break;
            }
            if(!occupied){V2i result={(int32_t)c,(int32_t)d};free(candidates);free(peers);return result;}
        }
    }
    free(candidates);free(peers);return none;
bad:
    free(candidates);free(peers);return invalid;
}
static void indexed_call(void *unused,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr *args,GDExtensionInt count,GDExtensionVariantPtr ret,GDExtensionCallError *error){
    (void)unused;(void)instance;V2i result={-2,-2};
    const GDExtensionVariantType types[6]={GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,GDEXTENSION_VARIANT_TYPE_FLOAT,GDEXTENSION_VARIANT_TYPE_FLOAT,GDEXTENSION_VARIANT_TYPE_INT};
    if(count!=6){error->error=count<6?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=6;from_v2i(ret,&result);return;}
    for(int i=0;i<6;i++)if(variant_type(args[i])!=types[i]){error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;error->argument=i;error->expected=types[i];from_v2i(ret,&result);return;}
    result=find_first_indexed(raw_array((void *)args[0]),raw_array((void *)args[1]),raw_delays((void *)args[2]),*(double *)raw_float((void *)args[3]),*(double *)raw_float((void *)args[4]),*(int64_t *)raw_int((void *)args[5]));
    error->error=GDEXTENSION_CALL_OK;from_v2i(ret,&result);
}
static GDExtensionObjectPtr create_query(void *unused){
    (void)unused;GDExtensionObjectPtr object=construct_object(&parent_name);void *state=calloc(1,1);set_instance(object,&class_name,state);return object;
}
static void free_query(void *unused,GDExtensionClassInstancePtr instance){(void)unused;free(instance);}
static void initialize(void *unused,GDExtensionInitializationLevel level){
    (void)unused;if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
    name_new(&class_name,"RoundCardSafeLayoutMath",0);name_new(&parent_name,"RefCounted",0);
    GDExtensionClassCreationInfo2 info={0};info.is_exposed=1;info.create_instance_func=create_query;info.free_instance_func=free_query;register_class(library,&class_name,&parent_name,&info);
    Name method,empty;uint64_t text=0;name_new(&method,"find_first",0);name_new(&empty,"",0);string_new(&text,"");
    GDExtensionPropertyInfo params[5]={{0}},returned={0};GDExtensionClassMethodArgumentMetadata metadata[5]={0};
    for(int i=0;i<5;i++){params[i].type=i<2?GDEXTENSION_VARIANT_TYPE_ARRAY:i==2?GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY:GDEXTENSION_VARIANT_TYPE_FLOAT;params[i].name=&empty;params[i].class_name=&empty;params[i].hint_string=&text;}
    returned.type=GDEXTENSION_VARIANT_TYPE_VECTOR2I;returned.name=&empty;returned.class_name=&empty;returned.hint_string=&text;
    GDExtensionClassMethodInfo m={0};m.name=&method;m.call_func=query_call;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.has_return_value=1;m.return_value_info=&returned;m.argument_count=5;m.arguments_info=params;m.arguments_metadata=metadata;
    register_method(library,&class_name,&m);name_free(&method);
    Name indexed_method;name_new(&indexed_method,"find_first_indexed",0);
    GDExtensionPropertyInfo indexed_params[6]={{0}};GDExtensionClassMethodArgumentMetadata indexed_metadata[6]={0};
    for(int i=0;i<6;i++){indexed_params[i].type=i<2?GDEXTENSION_VARIANT_TYPE_ARRAY:i==2?GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY:i==5?GDEXTENSION_VARIANT_TYPE_INT:GDEXTENSION_VARIANT_TYPE_FLOAT;indexed_params[i].name=&empty;indexed_params[i].class_name=&empty;indexed_params[i].hint_string=&text;}
    m.name=&indexed_method;m.call_func=indexed_call;m.argument_count=6;m.arguments_info=indexed_params;m.arguments_metadata=indexed_metadata;
    register_method(library,&class_name,&m);name_free(&indexed_method);name_free(&empty);string_free(&text);
}
static void deinitialize(void *unused,GDExtensionInitializationLevel level){
    (void)unused;if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;unregister_class(library,&class_name);name_free(&class_name);name_free(&parent_name);
}
EXPORT GDExtensionBool roundcard_safe_layout_math_init(GDExtensionInterfaceGetProcAddress get,GDExtensionClassLibraryPtr lib,GDExtensionInitialization *init){
    library=lib;
#define LOAD(v,t,n) v=(t)get(n)
    LOAD(name_new,GDExtensionInterfaceStringNameNewWithLatin1Chars,"string_name_new_with_latin1_chars");LOAD(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");LOAD(construct_object,GDExtensionInterfaceClassdbConstructObject,"classdb_construct_object");LOAD(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance");LOAD(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass2,"classdb_register_extension_class2");LOAD(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");LOAD(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");LOAD(array_at,GDExtensionInterfaceArrayOperatorIndexConst,"array_operator_index_const");LOAD(variant_type,GDExtensionInterfaceVariantGetType,"variant_get_type");LOAD(delay_at,GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst,"packed_float64_array_operator_index_const");
    GDExtensionInterfaceVariantGetPtrDestructor destroy=(GDExtensionInterfaceVariantGetPtrDestructor)get("variant_get_ptr_destructor");name_free=destroy(GDEXTENSION_VARIANT_TYPE_STRING_NAME);string_free=destroy(GDEXTENSION_VARIANT_TYPE_STRING);
    GDExtensionInterfaceGetVariantGetInternalPtrFunc raw=(GDExtensionInterfaceGetVariantGetInternalPtrFunc)get("variant_get_ptr_internal_getter");raw_array=raw(GDEXTENSION_VARIANT_TYPE_ARRAY);raw_rect=raw(GDEXTENSION_VARIANT_TYPE_RECT2);raw_float=raw(GDEXTENSION_VARIANT_TYPE_FLOAT);raw_delays=raw(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY);raw_int=raw(GDEXTENSION_VARIANT_TYPE_INT);
    GDExtensionInterfaceGetVariantFromTypeConstructor from=(GDExtensionInterfaceGetVariantFromTypeConstructor)get("get_variant_from_type_constructor");from_v2i=from(GDEXTENSION_VARIANT_TYPE_VECTOR2I);
    GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin=(GDExtensionInterfaceVariantGetPtrBuiltinMethod)get("variant_get_ptr_builtin_method");Name size;name_new(&size,"size",0);array_size=builtin(GDEXTENSION_VARIANT_TYPE_ARRAY,&size,3173160232);delays_size=builtin(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,&size,3173160232);name_free(&size);
    init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=NULL;init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;return 1;
}

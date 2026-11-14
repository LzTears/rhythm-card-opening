/* SPDX-License-Identifier: MIT. Pure presentation mathematics; exact existing pixel geometry. */
#include "gdextension_interface.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#if defined(_WIN32)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif
#define F GDEXTENSION_VARIANT_TYPE_FLOAT
#define B GDEXTENSION_VARIANT_TYPE_BOOL
#define V GDEXTENSION_VARIANT_TYPE_VECTOR2
#define W GDEXTENSION_VARIANT_TYPE_VECTOR3
#define C GDEXTENSION_VARIANT_TYPE_COLOR
typedef struct {float x,y;} V2;
typedef struct {float x,y,z;} V3;
typedef struct {float r,g,b,a;} Color;
typedef struct {uint64_t value;} Name;
typedef struct {uint64_t value[2];} Packed;
typedef struct {V3 *vertices;Color *colors;int count,capacity;} Buffer;
typedef struct {Buffer ground,front;double alpha;int preview;V2 p;V3 right,up,forward;Packed merge_output[4],finish_output[4];int merge_initialized,finish_initialized;} Geometry;
static GDExtensionClassLibraryPtr library;
static GDExtensionInterfaceStringNameNewWithLatin1Chars name_new;
static GDExtensionInterfaceStringNewWithUtf8Chars string_new;
static GDExtensionPtrDestructor name_free,string_free,packed_v_free,packed_c_free,array_free;
static GDExtensionInterfaceClassdbConstructObject construct_object;
static GDExtensionInterfaceObjectSetInstance set_instance;
static GDExtensionInterfaceClassdbRegisterExtensionClass2 register_class;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionVariantGetInternalPtrFunc raw_float,raw_bool,raw_v2,raw_v3,raw_color;
static GDExtensionVariantGetInternalPtrFunc raw_array,raw_pv,raw_pc;
static GDExtensionVariantFromTypeConstructorFunc from_int,from_pv,from_pc,from_array;
static GDExtensionInterfaceArrayOperatorIndex array_at;
static GDExtensionInterfaceArrayOperatorIndexConst array_at_const;
static GDExtensionInterfaceVariantDestroy variant_free;
static GDExtensionInterfaceVariantGetType variant_type;
static GDExtensionInterfacePackedVector3ArrayOperatorIndex packed_v_at;
static GDExtensionInterfacePackedColorArrayOperatorIndex packed_c_at;
static GDExtensionInterfacePackedVector3ArrayOperatorIndexConst packed_v_at_const;
static GDExtensionInterfacePackedColorArrayOperatorIndexConst packed_c_at_const;
static GDExtensionPtrConstructor packed_v_new,packed_c_new,array_new;
static GDExtensionPtrBuiltInMethod from_angle,snapped,lerp_v2,resize_v,resize_c,resize_a;
static GDExtensionPtrBuiltInMethod array_size,packed_v_size,packed_c_size;
/* Atlas packing is a separate byte-copy API; the nine geometry operations below
 * keep their original data, arithmetic and ordering. */
static GDExtensionVariantGetInternalPtrFunc raw_int,raw_pf32,raw_pi32,raw_pi64,raw_pf64;
static GDExtensionVariantFromTypeConstructorFunc from_pf32;
static GDExtensionPtrConstructor packed_f32_new,packed_f32_copy;
static GDExtensionPtrDestructor packed_f32_free;
static GDExtensionInterfacePackedFloat32ArrayOperatorIndex packed_f32_at;
static GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst packed_f32_at_const;
static GDExtensionInterfacePackedInt32ArrayOperatorIndexConst packed_i32_at_const;
static GDExtensionInterfacePackedInt64ArrayOperatorIndexConst packed_i64_at_const;
static GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst packed_f64_at_const;
static GDExtensionPtrBuiltInMethod packed_f32_size,packed_i32_size,packed_i64_size,packed_f64_size;
static Name class_name,parent_name;
#define FULL_CIRCLE_TAU 6.283185307179586
/* Filled through the exact engine builtin once at SCENE initialization, before
 * registering the class. All presentation calls only read this table. */
static V2 ground_full_circle[193][193];
static V3 add(V3 a,V3 b){return(V3){a.x+b.x,a.y+b.y,a.z+b.z};}
static V3 sub(V3 a,V3 b){return(V3){a.x-b.x,a.y-b.y,a.z-b.z};}
static V3 mul(V3 a,float k){return(V3){a.x*k,a.y*k,a.z*k};}
static int clamp_count(int v,int lo,int hi){return v<lo?lo:v>hi?hi:v;}
static V2 direction(double angle){V2 v;const void *args[]={&angle};from_angle(NULL,args,&v,1);return v;}
static V2 snap(V2 p,float cell){V2 v,step={cell,cell};const void *args[]={&step};snapped(&p,args,&v,1);return v;}
static V2 lerp(V2 a,V2 b,double weight){V2 v;const void *args[]={&b,&weight};lerp_v2(&a,args,&v,2);return v;}
static int capacity(Buffer *b,int count){
    if(count<=b->capacity)return 1;
    int cap=count*2+768;V3 *v=malloc((size_t)cap*sizeof(V3));Color *c=malloc((size_t)cap*sizeof(Color));
    if(!v||!c){free(v);free(c);return 0;}
    if(b->count){memcpy(v,b->vertices,(size_t)b->count*6*sizeof(V3));memcpy(c,b->colors,(size_t)b->count*6*sizeof(Color));}
    free(b->vertices);free(b->colors);b->vertices=v;b->colors=c;b->capacity=cap;return 1;
}
static void quad(Buffer *b,V3 a,V3 bb,V3 c,V3 d,Color color){
    int first=b->count*6;if(!capacity(b,first+6))return;
    V3 *v=b->vertices+first;Color *colors=b->colors+first;
    v[0]=a;v[1]=bb;v[2]=c;v[3]=bb;v[4]=d;v[5]=c;
    for(int i=0;i<6;i++)colors[i]=color;b->count++;
}
static void pixel(Geometry *g,V2 p,Color color,double half_size){
    p=snap(p,.035f);
    if((double)p.x-half_size< -7.2 || (double)p.x+half_size>7.2 || (double)p.y-half_size<0.0 || (double)p.y+half_size>6.0)return;
    color.a=(float)(g->alpha*(g->preview?.75:.9));
    float h=(float)half_size;V3 at={p.x,.075f,-p.y};
    quad(&g->ground,add(at,(V3){-h,0,-h}),add(at,(V3){h,0,-h}),add(at,(V3){-h,0,h}),add(at,(V3){h,0,h}),color);
}
static void front_pixel(Geometry *g,V2 p,Color color,double half_size){
    p=snap(p,.025f);
    if(g->p.x< -7.2f || g->p.x>7.2f || g->p.y<0.0f || g->p.y>6.0f)return;
    color.a=(float)(g->alpha*fmin(1.0,(double)color.a));
    V3 center=add(add(add((V3){g->p.x,.075f,-g->p.y},mul(g->forward,.76f)),mul(g->right,p.x)),mul(g->up,p.y));
    V3 across=mul(g->right,(float)half_size),up=mul(g->up,(float)half_size);
    quad(&g->front,sub(sub(center,across),up),sub(add(center,across),up),add(sub(center,across),up),add(add(center,across),up),color);
}
static void arc(Geometry *g,V2 center,double radius,double start,double sweep,Color color,int dashed,double scale,int front){
    if((front && radius<.015) || (!front && (radius<=.001 || sweep<=.001)) || (front && scale<.002))return;
    int count=clamp_count((int)ceil(front?radius*sweep/.045:sweep*radius/.035),8,front?80:192);
    const V2 *circle=(!front && start==0.0 && sweep==FULL_CIRCLE_TAU)?ground_full_circle[count]:NULL;
    for(int i=0;i<=count;i++){
        if(!front && dashed && i%4>=2)continue;
        double angle=front?start+(double)i/count*sweep:start+sweep*(double)i/(double)count;
        V2 d=circle?circle[i]:direction(angle);V2 p={center.x+d.x*(float)radius,center.y+d.y*(float)radius};
        if(front)front_pixel(g,p,color,scale);else pixel(g,p,color,.035*scale);
    }
}
static void segment(Geometry *g,V2 start,V2 end,Color color,int dashed,double scale,int front){
    if(front && scale<.002)return;
    float dx=start.x-end.x,dy=start.y-end.y;float length=sqrtf(dx*dx+dy*dy);
    int count=clamp_count((int)ceil((double)length/(front?.035:.035)),1,front?80:160);
    for(int i=0;i<=count;i++){
        if(!front && dashed && i%4>=2)continue;
        V2 p=lerp(start,end,(double)i/count);
        if(front)front_pixel(g,p,color,scale);else pixel(g,p,color,.035*scale);
    }
}
static double f(const GDExtensionConstVariantPtr *args,int i){return *(double *)raw_float((void *)args[i]);}
static V2 v(const GDExtensionConstVariantPtr *args,int i){return *(V2 *)raw_v2((void *)args[i]);}
static Color c(const GDExtensionConstVariantPtr *args,int i){return *(Color *)raw_color((void *)args[i]);}
static int boolean(const GDExtensionConstVariantPtr *args,int i){return *(uint8_t *)raw_bool((void *)args[i]);}
static void packed(Buffer *buffer,Packed *output,void *array,int index){
    int64_t count=(int64_t)buffer->count*6,result=0;const void *args[]={&count};
    Packed *vertices=&output[index],*colors=&output[index+1];
    resize_v(vertices,args,&result,1);resize_c(colors,args,&result,1);
    /* The engine's writable accessor detaches any externally retained snapshot.
     * Otherwise the same per-effect packed storage is overwritten in place. */
    if(count){memcpy(packed_v_at(vertices,0),buffer->vertices,(size_t)count*sizeof(V3));memcpy(packed_c_at(colors,0),buffer->colors,(size_t)count*sizeof(Color));}
    void *dest=array_at(array,index);variant_free(dest);from_pv(dest,vertices);
    dest=array_at(array,index+1);variant_free(dest);from_pc(dest,colors);
}
typedef struct {
    const V3 *ground_vertices,*front_vertices;
    const Color *ground_colors,*front_colors;
    int64_t ground_size,front_size;
} MergeSource;
static int64_t builtin_size(GDExtensionPtrBuiltInMethod method,const void *value){
    int64_t result=0;method((void *)value,NULL,&result,0);return result;
}
static void empty_array(GDExtensionVariantPtr ret){
    uint64_t array=0;array_new(&array,NULL);from_array(ret,&array);array_free(&array);
}
/* Concatenate immutable packed sources in input/vertex order. Lengths are counted
 * before allocating each destination exactly once; no geometry or float arithmetic
 * is performed here. An invalid source declines to the caller's original fallback. */
static void merge_packed_sources(Geometry *g,GDExtensionConstVariantPtr argument,GDExtensionVariantPtr ret){
    void *rows=raw_array((void *)argument);
    int64_t count=builtin_size(array_size,rows),ground_total=0,front_total=0;
    if(count<0 || (uint64_t)count>SIZE_MAX/sizeof(MergeSource)){empty_array(ret);return;}
    MergeSource *sources=count?malloc((size_t)count*sizeof(MergeSource)):NULL;
    if(count && !sources){empty_array(ret);return;}
    for(int64_t i=0;i<count;i++){
        GDExtensionVariantPtr row_variant=array_at_const(rows,i);
        if(variant_type(row_variant)!=GDEXTENSION_VARIANT_TYPE_ARRAY)goto invalid;
        void *row=raw_array(row_variant);
        if(builtin_size(array_size,row)!=4)goto invalid;
        GDExtensionVariantPtr values[4];
        for(int k=0;k<4;k++){
            values[k]=array_at_const(row,k);
            GDExtensionVariantType expected=k%2?GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY:GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY;
            if(variant_type(values[k])!=expected)goto invalid;
        }
        void *gv=raw_pv(values[0]),*gc=raw_pc(values[1]),*fv=raw_pv(values[2]),*fc=raw_pc(values[3]);
        int64_t ng=builtin_size(packed_v_size,gv),nf=builtin_size(packed_v_size,fv);
        if(ng<0 || nf<0 || ng!=builtin_size(packed_c_size,gc) || nf!=builtin_size(packed_c_size,fc))goto invalid;
        if(ng>INT32_MAX-ground_total || nf>INT32_MAX-front_total)goto invalid;
        ground_total+=ng;front_total+=nf;
        sources[i]=(MergeSource){ng?(const V3 *)packed_v_at_const(gv,0):NULL,nf?(const V3 *)packed_v_at_const(fv,0):NULL,ng?(const Color *)packed_c_at_const(gc,0):NULL,nf?(const Color *)packed_c_at_const(fc,0):NULL,ng,nf};
    }
    if(!g->merge_initialized){
        for(int k=0;k<4;k++)(k%2?packed_c_new:packed_v_new)(&g->merge_output[k],NULL);
        g->merge_initialized=1;
    }
    Packed *output=g->merge_output;
    for(int k=0;k<4;k++){
        int64_t size=k<2?ground_total:front_total,result=0;const void *args[]={&size};
        (k%2?resize_c:resize_v)(&output[k],args,&result,1);
        if(result!=0)goto invalid;
    }
    V3 *gv=ground_total?packed_v_at(&output[0],0):NULL,*fv=front_total?packed_v_at(&output[2],0):NULL;
    Color *gc=ground_total?packed_c_at(&output[1],0):NULL,*fc=front_total?packed_c_at(&output[3],0):NULL;
    int64_t go=0,fo=0;
    for(int64_t i=0;i<count;i++){
        MergeSource *source=&sources[i];
        if(source->ground_size){memcpy(gv+go,source->ground_vertices,(size_t)source->ground_size*sizeof(V3));memcpy(gc+go,source->ground_colors,(size_t)source->ground_size*sizeof(Color));go+=source->ground_size;}
        if(source->front_size){memcpy(fv+fo,source->front_vertices,(size_t)source->front_size*sizeof(V3));memcpy(fc+fo,source->front_colors,(size_t)source->front_size*sizeof(Color));fo+=source->front_size;}
    }
    uint64_t array=0;array_new(&array,NULL);int64_t size=4,result=0;const void *args[]={&size};resize_a(&array,args,&result,1);
    for(int k=0;k<4;k++){
        void *dest=array_at(&array,k);variant_free(dest);(k%2?from_pc:from_pv)(dest,&output[k]);
    }
    from_array(ret,&array);array_free(&array);free(sources);return;
invalid:
    free(sources);empty_array(ret);
}
static void empty_float32(GDExtensionVariantPtr ret){
    Packed value;packed_f32_new(&value,NULL);from_pf32(ret,&value);packed_f32_free(&value);
}
static void fill_atlas_rows(const GDExtensionConstVariantPtr *args,GDExtensionVariantPtr ret){
    void *input=raw_pf32((void *)args[0]),*rows=raw_array((void *)args[1]);
    void *slots=raw_pi32((void *)args[2]),*frames=raw_pi64((void *)args[3]),*opacities=raw_pf64((void *)args[4]);
    int64_t columns=*(int64_t *)raw_int((void *)args[5]),grid_rows=*(int64_t *)raw_int((void *)args[6]);
    int64_t count=builtin_size(array_size,rows),size=builtin_size(packed_f32_size,input);
    if(count<0 || size<0 || size%16 || columns<=0 || grid_rows<=0 || columns>INT64_MAX/grid_rows ||
       builtin_size(packed_i32_size,slots)!=count || builtin_size(packed_i64_size,frames)!=count || builtin_size(packed_f64_size,opacities)!=count){empty_float32(ret);return;}
    const int32_t *indices=count?packed_i32_at_const(slots,0):NULL;
    const int64_t *cells=count?packed_i64_at_const(frames,0):NULL;
    const double *alpha=count?packed_f64_at_const(opacities,0):NULL;
    /* Validate the entire transaction before requesting any writable storage.
     * Frames are already clamped to each source's actual authored frame count
     * by GDScript, not merely to this grid's possibly unused final-row cells. */
    for(int64_t i=0;i<count;i++){
        GDExtensionVariantPtr value=array_at_const(rows,i);
        if(variant_type(value)!=GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY || indices[i]<0 || (int64_t)indices[i]>=size/16 ||
           cells[i]<0 || cells[i]>=columns*grid_rows || !isfinite(alpha[i])){empty_float32(ret);return;}
        void *row=raw_pf32(value);
        if(builtin_size(packed_f32_size,row)!=16){empty_float32(ret);return;}
        const float *source=packed_f32_at_const(row,0);
        for(int k=0;k<12;k++)if(!isfinite(source[k])){empty_float32(ret);return;}
    }
    Packed output;const void *copy_args[]={input};packed_f32_copy(&output,copy_args);
    /* Godot's writable accessor performs COW. The caller's input, retained old
     * snapshots and even a source row aliasing input remain untouched. */
    float *destination=count?packed_f32_at(&output,0):NULL;
    for(int64_t i=0;i<count;i++){
        void *row=raw_pf32(array_at_const(rows,i));
        float *target=destination+(int64_t)indices[i]*16;
        memcpy(target,packed_f32_at_const(row,0),12*sizeof(float));
        target[12]=(float)((double)(cells[i]%columns)/(double)columns);
        target[13]=(float)((double)(cells[i]/columns)/(double)grid_rows);
        target[14]=(float)fmin(1.0,fmax(0.0,alpha[i]));
        target[15]=0.0f;
    }
    from_pf32(ret,&output);packed_f32_free(&output);
}
static void invoke(void *userdata,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr *args,GDExtensionInt count,GDExtensionVariantPtr ret,GDExtensionCallError *error){
    Geometry *g=instance;int op=(int)(uintptr_t)userdata;int64_t result=0;
    static const int counts[10]={6,7,5,3,7,5,4,0,1,7};
    static const GDExtensionVariantType types[10][7]={{F,B,V,W,W,W},{V,F,F,F,C,B,F},{V,V,C,B,F},{V,C,F},{V,F,F,F,C,F,F},{V,V,C,F,F},{V,C,F,F},{0},{GDEXTENSION_VARIANT_TYPE_ARRAY},{GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,GDEXTENSION_VARIANT_TYPE_INT,GDEXTENSION_VARIANT_TYPE_INT}};
    if(op<0 || op>9 || !g){error->error=GDEXTENSION_CALL_ERROR_INSTANCE_IS_NULL;from_int(ret,&result);return;}
    if(count!=counts[op]){error->error=count<counts[op]?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=counts[op];from_int(ret,&result);return;}
    for(int i=0;i<count;i++)if(variant_type(args[i])!=types[op][i]){error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;error->argument=i;error->expected=types[op][i];from_int(ret,&result);return;}
    switch(op){
      case 0:g->ground.count=0;g->front.count=0;g->alpha=f(args,0);g->preview=boolean(args,1);g->p=v(args,2);g->right=*(V3 *)raw_v3((void *)args[3]);g->up=*(V3 *)raw_v3((void *)args[4]);g->forward=*(V3 *)raw_v3((void *)args[5]);break;
      case 1:arc(g,v(args,0),f(args,1),f(args,2),f(args,3),c(args,4),boolean(args,5),f(args,6),0);result=g->ground.count;break;
      case 2:segment(g,v(args,0),v(args,1),c(args,2),boolean(args,3),f(args,4),0);result=g->ground.count;break;
      case 3:pixel(g,v(args,0),c(args,1),f(args,2));result=g->ground.count;break;
      case 4:g->alpha=f(args,6);arc(g,v(args,0),f(args,1),f(args,2),f(args,3),c(args,4),0,f(args,5),1);result=g->front.count;break;
      case 5:g->alpha=f(args,4);segment(g,v(args,0),v(args,1),c(args,2),0,f(args,3),1);result=g->front.count;break;
      case 6:g->alpha=f(args,3);front_pixel(g,v(args,0),c(args,1),f(args,2));result=g->front.count;break;
      case 7:{if(!g->finish_initialized){for(int k=0;k<4;k++)(k%2?packed_c_new:packed_v_new)(&g->finish_output[k],NULL);g->finish_initialized=1;}uint64_t array=0;array_new(&array,NULL);int64_t size=4,unused=0;const void *args_resize[]={&size};resize_a(&array,args_resize,&unused,1);packed(&g->ground,g->finish_output,&array,0);packed(&g->front,g->finish_output,&array,2);from_array(ret,&array);array_free(&array);error->error=GDEXTENSION_CALL_OK;return;}
      case 8:merge_packed_sources(g,args[0],ret);error->error=GDEXTENSION_CALL_OK;return;
      case 9:fill_atlas_rows(args,ret);error->error=GDEXTENSION_CALL_OK;return;
    }
    from_int(ret,&result);error->error=GDEXTENSION_CALL_OK;
}
static GDExtensionObjectPtr create(void *unused){(void)unused;void *object=construct_object(&parent_name);Geometry *g=calloc(1,sizeof(Geometry));set_instance(object,&class_name,g);return object;}
static void destroy(void *unused,GDExtensionClassInstancePtr instance){(void)unused;Geometry *g=instance;free(g->ground.vertices);free(g->ground.colors);free(g->front.vertices);free(g->front.colors);if(g->merge_initialized)for(int k=0;k<4;k++)(k%2?packed_c_free:packed_v_free)(&g->merge_output[k]);if(g->finish_initialized)for(int k=0;k<4;k++)(k%2?packed_c_free:packed_v_free)(&g->finish_output[k]);free(g);}
static void method(const char *text,int op,int argc,const GDExtensionVariantType *types,int array_return){
    Name name,empty;uint64_t empty_string=0;name_new(&name,text,0);name_new(&empty,"",0);string_new(&empty_string,"");
    GDExtensionPropertyInfo params[7]={{0}},returned={0};GDExtensionClassMethodArgumentMetadata metadata[7]={0};
    for(int i=0;i<argc;i++){params[i].type=types[i];params[i].name=&empty;params[i].class_name=&empty;params[i].hint_string=&empty_string;}
    returned.type=array_return==2?GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY:(array_return?GDEXTENSION_VARIANT_TYPE_ARRAY:GDEXTENSION_VARIANT_TYPE_INT);returned.name=&empty;returned.class_name=&empty;returned.hint_string=&empty_string;
    GDExtensionClassMethodInfo info={0};info.name=&name;info.method_userdata=(void *)(uintptr_t)op;info.call_func=invoke;info.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;info.has_return_value=1;info.return_value_info=&returned;info.argument_count=argc;info.arguments_info=params;info.arguments_metadata=metadata;
    register_method(library,&class_name,&info);name_free(&name);name_free(&empty);string_free(&empty_string);
}
static void initialize(void *unused,GDExtensionInitializationLevel level){
    (void)unused;if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
    for(int count=8;count<=192;count++)for(int i=0;i<=count;i++){
        double angle=0.0+FULL_CIRCLE_TAU*(double)i/(double)count;
        ground_full_circle[count][i]=direction(angle);
    }
    name_new(&class_name,"RoundCardGeometryMath",0);name_new(&parent_name,"RefCounted",0);
    GDExtensionClassCreationInfo2 info={0};info.is_exposed=1;info.create_instance_func=create;info.free_instance_func=destroy;register_class(library,&class_name,&parent_name,&info);
#define F GDEXTENSION_VARIANT_TYPE_FLOAT
#define B GDEXTENSION_VARIANT_TYPE_BOOL
#define V GDEXTENSION_VARIANT_TYPE_VECTOR2
#define W GDEXTENSION_VARIANT_TYPE_VECTOR3
#define C GDEXTENSION_VARIANT_TYPE_COLOR
    method("reset",0,6,(GDExtensionVariantType[]){F,B,V,W,W,W},0);
    method("arc",1,7,(GDExtensionVariantType[]){V,F,F,F,C,B,F},0);
    method("segment",2,5,(GDExtensionVariantType[]){V,V,C,B,F},0);
    method("pixel",3,3,(GDExtensionVariantType[]){V,C,F},0);
    method("front_arc",4,7,(GDExtensionVariantType[]){V,F,F,F,C,F,F},0);
    method("front_segment",5,5,(GDExtensionVariantType[]){V,V,C,F,F},0);
    method("front_pixel",6,4,(GDExtensionVariantType[]){V,C,F,F},0);
    method("finish",7,0,NULL,1);
    method("merge",8,1,(GDExtensionVariantType[]){GDEXTENSION_VARIANT_TYPE_ARRAY},1);
    method("fill_atlas_rows",9,7,(GDExtensionVariantType[]){GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,GDEXTENSION_VARIANT_TYPE_INT,GDEXTENSION_VARIANT_TYPE_INT},2);
}
static void deinitialize(void *unused,GDExtensionInitializationLevel level){(void)unused;if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;unregister_class(library,&class_name);name_free(&class_name);name_free(&parent_name);}
EXPORT GDExtensionBool roundcard_geometry_init(GDExtensionInterfaceGetProcAddress get,GDExtensionClassLibraryPtr lib,GDExtensionInitialization *init){
    library=lib;
#define LOAD(v,t,n) v=(t)get(n)
    LOAD(name_new,GDExtensionInterfaceStringNameNewWithLatin1Chars,"string_name_new_with_latin1_chars");LOAD(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");LOAD(construct_object,GDExtensionInterfaceClassdbConstructObject,"classdb_construct_object");LOAD(set_instance,GDExtensionInterfaceObjectSetInstance,"object_set_instance");LOAD(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass2,"classdb_register_extension_class2");LOAD(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");LOAD(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");LOAD(array_at,GDExtensionInterfaceArrayOperatorIndex,"array_operator_index");LOAD(variant_free,GDExtensionInterfaceVariantDestroy,"variant_destroy");LOAD(variant_type,GDExtensionInterfaceVariantGetType,"variant_get_type");LOAD(packed_v_at,GDExtensionInterfacePackedVector3ArrayOperatorIndex,"packed_vector3_array_operator_index");LOAD(packed_c_at,GDExtensionInterfacePackedColorArrayOperatorIndex,"packed_color_array_operator_index");
    GDExtensionInterfaceVariantGetPtrDestructor destructor=(GDExtensionInterfaceVariantGetPtrDestructor)get("variant_get_ptr_destructor");name_free=destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);string_free=destructor(GDEXTENSION_VARIANT_TYPE_STRING);packed_v_free=destructor(GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY);packed_c_free=destructor(GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY);array_free=destructor(GDEXTENSION_VARIANT_TYPE_ARRAY);
    LOAD(array_at_const,GDExtensionInterfaceArrayOperatorIndexConst,"array_operator_index_const");LOAD(packed_v_at_const,GDExtensionInterfacePackedVector3ArrayOperatorIndexConst,"packed_vector3_array_operator_index_const");LOAD(packed_c_at_const,GDExtensionInterfacePackedColorArrayOperatorIndexConst,"packed_color_array_operator_index_const");
    GDExtensionInterfaceGetVariantGetInternalPtrFunc raw=(GDExtensionInterfaceGetVariantGetInternalPtrFunc)get("variant_get_ptr_internal_getter");raw_float=raw(F);raw_bool=raw(B);raw_v2=raw(V);raw_v3=raw(W);raw_color=raw(C);raw_array=raw(GDEXTENSION_VARIANT_TYPE_ARRAY);raw_pv=raw(GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY);raw_pc=raw(GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY);
    GDExtensionInterfaceGetVariantFromTypeConstructor from=(GDExtensionInterfaceGetVariantFromTypeConstructor)get("get_variant_from_type_constructor");from_int=from(GDEXTENSION_VARIANT_TYPE_INT);from_pv=from(GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY);from_pc=from(GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY);from_array=from(GDEXTENSION_VARIANT_TYPE_ARRAY);
    GDExtensionInterfaceVariantGetPtrConstructor ctor=(GDExtensionInterfaceVariantGetPtrConstructor)get("variant_get_ptr_constructor");packed_v_new=ctor(GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY,0);packed_c_new=ctor(GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY,0);array_new=ctor(GDEXTENSION_VARIANT_TYPE_ARRAY,0);
    GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin=(GDExtensionInterfaceVariantGetPtrBuiltinMethod)get("variant_get_ptr_builtin_method");Name name;
#define BUILTIN(dest,type,text,hash) name_new(&name,text,0);dest=builtin(type,&name,hash);name_free(&name)
    BUILTIN(from_angle,V,"from_angle",889263119);BUILTIN(snapped,V,"snapped",2026743667);BUILTIN(lerp_v2,V,"lerp",4250033116);BUILTIN(resize_v,GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY,"resize",848867239);BUILTIN(resize_c,GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY,"resize",848867239);BUILTIN(resize_a,GDEXTENSION_VARIANT_TYPE_ARRAY,"resize",848867239);
    BUILTIN(array_size,GDEXTENSION_VARIANT_TYPE_ARRAY,"size",3173160232);BUILTIN(packed_v_size,GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY,"size",3173160232);BUILTIN(packed_c_size,GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY,"size",3173160232);
    raw_int=raw(GDEXTENSION_VARIANT_TYPE_INT);raw_pf32=raw(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY);raw_pi32=raw(GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY);raw_pi64=raw(GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY);raw_pf64=raw(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY);
    from_pf32=from(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY);packed_f32_new=ctor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,0);packed_f32_copy=ctor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,1);packed_f32_free=destructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY);
    LOAD(packed_f32_at,GDExtensionInterfacePackedFloat32ArrayOperatorIndex,"packed_float32_array_operator_index");LOAD(packed_f32_at_const,GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst,"packed_float32_array_operator_index_const");LOAD(packed_i32_at_const,GDExtensionInterfacePackedInt32ArrayOperatorIndexConst,"packed_int32_array_operator_index_const");LOAD(packed_i64_at_const,GDExtensionInterfacePackedInt64ArrayOperatorIndexConst,"packed_int64_array_operator_index_const");LOAD(packed_f64_at_const,GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst,"packed_float64_array_operator_index_const");
    BUILTIN(packed_f32_size,GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,"size",3173160232);BUILTIN(packed_i32_size,GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY,"size",3173160232);BUILTIN(packed_i64_size,GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,"size",3173160232);BUILTIN(packed_f64_size,GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,"size",3173160232);
    init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=NULL;init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;return 1;
}

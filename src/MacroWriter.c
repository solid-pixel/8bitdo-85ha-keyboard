// Scoped macro operations for the wired 85HA, using USB interrupt transfers only.
#include <libusb.h>
#include "Macro.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
static volatile sig_atomic_t interrupted;
static void stop(int sig){(void)sig;interrupted=1;}
static void dump(const char *label,const uint8_t *p,unsigned n){printf("%s ",label);for(unsigned i=0;i<n;i++)printf("%02x",p[i]);puts("");fflush(stdout);}
// Pre-post input transfers so burst replies cannot fall between synchronous reads.
struct input_queue {struct libusb_transfer *slots[16];uint8_t buffers[16][33],packets[64][33];unsigned head,count,pending;int stopping,error;libusb_context *ctx;} q;
static void arrived(struct libusb_transfer *t){
 q.pending--;
 if(t->status==LIBUSB_TRANSFER_COMPLETED&&t->actual_length==33){
  if(q.count==64)q.error=1;else{memcpy(q.packets[(q.head+q.count)%64],t->buffer,33);q.count++;}
 }else if(!q.stopping)q.error=1;
 if(!q.stopping){if(libusb_submit_transfer(t))q.error=1;else q.pending++;}
}
static int receive(uint8_t reply[33]){
 struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);long long end=t.tv_sec*1000LL+t.tv_nsec/1000000+2500;
 for(;;){
  if(interrupted||q.error)return -1;
  if(q.count){memcpy(reply,q.packets[q.head],33);q.head=(q.head+1)%64;q.count--;dump("RX",reply,33);if(reply[0]!=0x54)return -1;if(reply[1]==0x8a)continue;return 0;}
  clock_gettime(CLOCK_MONOTONIC,&t);if(t.tv_sec*1000LL+t.tv_nsec/1000000>=end)return -1;
  struct timeval tv={0,20000};if(libusb_handle_events_timeout(q.ctx,&tv))return -1;
 }
}
static int send_packet(libusb_device_handle *h,uint8_t out,const uint8_t packet[33]){if(interrupted)return -1;int n=0;dump("TX",packet,33);int r=libusb_interrupt_transfer(h,out,(uint8_t *)packet,33,&n,1500);return r||n!=33?-1:0;}
static int ack(void){uint8_t p[33];return receive(p)||memcmp(p,"\x54\xe4\x08",3)?-1:0;}
static int query(libusb_device_handle *h,uint8_t out,uint8_t cmd,uint8_t key,uint8_t reply[33]){
 if(cmd!=0x80&&cmd!=0x82&&cmd!=0x83&&cmd!=0x84&&cmd!=0x86)return -1;
 uint8_t p[33]={0x52,cmd,0};if(cmd>=0x83)p[2]=key;
 return send_packet(h,out,p)||receive(reply)||reply[1]!=cmd||(cmd>=0x83&&reply[2]!=key)?-1:0;
}
static int read_macro(libusb_device_handle *h,uint8_t out,uint8_t key,uint8_t name[33],uint8_t data[MACRO_MAX_BYTES],unsigned *length){
 uint8_t p[33];*length=0;if(query(h,out,0x84,key,name)||query(h,out,0x86,key,p))return -1;
 for(unsigned page=0;;page++){
  if(p[0]!=0x54||p[1]!=0x86||p[2]!=key||p[3]>1||!p[6]||p[6]>26||p[4]+256u*p[5]!=*length||*length+p[6]>MACRO_MAX_BYTES||page>16)return -1;
  memcpy(data+*length,p+7,p[6]);*length+=p[6];if(!p[3])return 0;if(receive(p))return -1;
 }
}
static int list_has(const uint8_t p[33],uint8_t key){for(unsigned i=2;i+3<32;i+=4){if(!p[i])break;if(p[i]==key)return 1;}return 0;}
static int list_matches(const uint8_t before[33],const uint8_t after[33],uint8_t key,int remove,unsigned dataSize,unsigned nameSize){
 if(after[0]!=0x54||after[1]!=0x82||after[32])return 0;
 uint8_t a[256][3]={{0}},b[256][3]={{0}},sa[256]={0},sb[256]={0};
 for(unsigned i=2;i+3<32;i+=4){if(!before[i])break;if(sa[before[i]])return 0;sa[before[i]]=1;memcpy(a[before[i]],before+i+1,3);}
 for(unsigned i=2;i+3<32;i+=4){if(!after[i])break;if(sb[after[i]])return 0;sb[after[i]]=1;memcpy(b[after[i]],after+i+1,3);}
 for(unsigned k=1;k<256;k++)if(k!=key&&(sa[k]!=sb[k]||memcmp(a[k],b[k],3)))return 0;
 return remove?!sb[key]:(sb[key]&&b[key][0]+256u*b[key][1]==dataSize&&b[key][2]==nameSize);
}
int main(int argc,char **argv){
 uint8_t key,expected[24],desired[24],name[33],macros[33],oldName[33]={0},oldData[MACRO_MAX_BYTES],newName[28],newData[MACRO_MAX_BYTES];
 unsigned oldSize=0,newSize=0,nameSize=0;int removing=argc==11&&!strcmp(argv[1],"--remove"),hadMacro=0;
 if(argc!=11||(!removing&&strcmp(argv[1],"--set"))||!parse_hex(argv[2],&key,1)||!physical_key(key)||!parse_hex(argv[3],expected,24)||!(zero_mapping(expected)||mapping_valid(expected))||!parse_hex(argv[4],desired,24)||!mapping_valid(desired)||!parse_hex(argv[5],name,33)||name[0]!=0x54||name[1]!=0x80||name[2]>28||name[2]%2||name[3]||!parse_hex(argv[6],macros,33)||macros[0]!=0x54||macros[1]!=0x82||macros[32]){fputs("Unsupported macro request.\n",stderr);return 2;}
 hadMacro=list_has(macros,key);
 if(!macro_list_writable(macros,33)){fputs("Macro table contains unsupported entries. No write attempted.\n",stderr);return 2;}
 if(!macro_writes_enabled()){fputs("Macro changes are paused: replacement is not reliable on this keyboard. No write attempted.\n",stderr);return 2;}
 if(hadMacro){oldSize=(unsigned)strlen(argv[8])/2;if(!parse_hex(argv[7],oldName,33)||oldName[0]!=0x54||oldName[1]!=0x84||oldName[2]!=key||oldName[4]||!macro_name_valid(oldName+5,oldName[3])||oldSize>MACRO_MAX_BYTES||!parse_hex(argv[8],oldData,oldSize)||!macro_valid(oldData,oldSize))return 2;}
 else if(strcmp(argv[7],"-")||strcmp(argv[8],"-")||removing)return 2;
 if(removing){if(strcmp(argv[9],"-")||strcmp(argv[10],"-"))return 2;}
 else{
  nameSize=(unsigned)strlen(argv[9])/2;newSize=(unsigned)strlen(argv[10])/2;
  // Undo may restore a macro whose original companion mapping was not Disabled.
  if(nameSize>28||!parse_hex(argv[9],newName,nameSize)||!macro_name_valid(newName,nameSize)||newSize>MACRO_MAX_BYTES||!parse_hex(argv[10],newData,newSize)||!macro_valid(newData,newSize))return 2;
  unsigned count=0;for(unsigned i=2;i+3<32;i+=4){if(!macros[i])break;count++;}if(!hadMacro&&count>=7){fputs("Macro list is full.\n",stderr);return 2;}
 }
 if(geteuid()!=0){fputs("Administrator authorization is required.\n",stderr);return 2;}
    signal(SIGINT,stop); signal(SIGTERM,stop); signal(SIGHUP,stop);
    libusb_context *ctx=NULL;libusb_device **list=NULL;libusb_device_handle *h=NULL;
    struct libusb_config_descriptor *config=NULL;
    int result=1,detached=0,claimed=0,count=0,r;
    uint8_t in=0,out=0;
    if((r=libusb_init(&ctx))) {fprintf(stderr,"Init: %s\n",libusb_error_name(r));goto cleanup;}
    ssize_t num=libusb_get_device_list(ctx,&list);libusb_device *target=NULL;
    if(num<0) goto cleanup;
    for(ssize_t i=0;i<num;i++) {
        struct libusb_device_descriptor d;
        if(!libusb_get_device_descriptor(list[i],&d) && d.idVendor==0x2dc8 && d.idProduct==0x5200) {target=list[i];count++;}
    }
    if(count!=1) {fprintf(stderr,"Expected one wired 85HA; found %d.\n",count);goto cleanup;}
    if((r=libusb_get_active_config_descriptor(target,&config))) goto error;
    int matches=0;
    for(int i=0;i<config->bNumInterfaces;i++) for(int j=0;j<config->interface[i].num_altsetting;j++) {
        const struct libusb_interface_descriptor *d=&config->interface[i].altsetting[j];
        if(d->bInterfaceNumber!=2 || d->bAlternateSetting!=0)continue;
        if(d->bInterfaceClass!=3 || d->bNumEndpoints!=2)goto cleanup;
        for(int k=0;k<d->bNumEndpoints;k++) {
            const struct libusb_endpoint_descriptor *e=&d->endpoint[k];
            if((e->bmAttributes&3)!=LIBUSB_TRANSFER_TYPE_INTERRUPT || e->wMaxPacketSize<33 || e->wMaxPacketSize>64)goto cleanup;
            if(e->bEndpointAddress&0x80){if(in)goto cleanup;in=e->bEndpointAddress;}
            else {if(out)goto cleanup;out=e->bEndpointAddress;}
        }
        matches++;
    }
    if(matches!=1 || in!=0x84 || out!=0x05)goto cleanup;
    printf("DEVICE 2dc8:5200 interface=2 in=%02x out=%02x\n",in,out);fflush(stdout);
    if((r=libusb_open(target,&h)))goto error;
    r=libusb_kernel_driver_active(h,2);
    if(r<0)goto error;
    if(r) {
        if((r=libusb_detach_kernel_driver(h,2)))goto error;
        detached=1;
    }
    if((r=libusb_claim_interface(h,2)))goto error;
    claimed=1;


    q.ctx=ctx;
    for(unsigned i=0;i<16;i++){
        q.slots[i]=libusb_alloc_transfer(0);if(!q.slots[i])goto cleanup;
        libusb_fill_interrupt_transfer(q.slots[i],h,in,q.buffers[i],33,arrived,NULL,0);
        if(libusb_submit_transfer(q.slots[i]))goto cleanup;q.pending++;
    }
    uint8_t reply[33],actualName[33],actualData[MACRO_MAX_BYTES];unsigned actualSize=0;
    if(query(h,out,0x80,0,reply)||memcmp(reply,name,33)){fputs("Profile changed. Reload.\n",stderr);goto cleanup;}
    if(query(h,out,0x82,0,reply)||memcmp(reply,macros,33)){fputs("Macro list changed. Reload.\n",stderr);goto cleanup;}
    if(query(h,out,0x83,key,reply)||memcmp(reply+3,expected,24)){fputs("Key mapping changed. Reload.\n",stderr);goto cleanup;}
    if(hadMacro&&(read_macro(h,out,key,actualName,actualData,&actualSize)||memcmp(actualName,oldName,33)||actualSize!=oldSize||memcmp(actualData,oldData,oldSize))){fputs("Macro changed or could not be backed up. No write.\n",stderr);goto cleanup;}
    uint8_t packet[33]={0x52,0x76,0xff};
    if(send_packet(h,out,packet)||ack()){fputs("Could not enter configuration mode.\n",stderr);goto cleanup;}
    usleep(150000);
    fputs("WRITE_ATTEMPTED\n",stderr);
    // The official legacy editor deletes the old definition before replacing it.
    // Writing a name over an existing allocation is not a supported update path.
    if(hadMacro){
        if(!macro_remove_packet(key,oldData,oldSize,packet))goto cleanup;
        if(send_packet(h,out,packet)||ack()){fputs("Macro removal not acknowledged.\n",stderr);goto cleanup;}
        usleep(150000);
        if(query(h,out,0x82,0,reply)||!list_matches(macros,reply,key,1,0,0)){fputs("Macro removal verification failed.\n",stderr);goto cleanup;}
    }
    if(!removing){
        memset(packet,0,33);packet[0]=0x52;packet[1]=0x74;packet[2]=key;packet[3]=nameSize;memcpy(packet+5,newName,nameSize);
        if(send_packet(h,out,packet)||ack()){fputs("Macro name not acknowledged.\n",stderr);goto cleanup;}
        usleep(150000);
        for(unsigned pos=0;pos<newSize;){unsigned size=macro_packet(key,newData,newSize,pos,packet);if(!size||send_packet(h,out,packet))goto cleanup;pos+=size;}
        if(ack()){fputs("Macro sequence not acknowledged.\n",stderr);goto cleanup;}
        if(read_macro(h,out,key,actualName,actualData,&actualSize)||actualName[3]!=nameSize||actualName[4]||memcmp(actualName+5,newName,nameSize)||actualSize!=newSize||memcmp(actualData,newData,newSize)){fputs("Macro readback failed. Stopped without retry.\n",stderr);goto cleanup;}
    }
    if(query(h,out,0x82,0,reply)||!list_matches(macros,reply,key,removing,newSize,nameSize)){fputs("Macro list verification failed.\n",stderr);goto cleanup;}
    // Suppress the ordinary key for a macro, or restore it after removal.
    if(!matches_readback(key,desired,expected)){
        uint8_t mapping[33]={0x52,0xfa,3,0x0c,0,0xaa,9,0x71,key};memcpy(mapping+9,desired,24);
        if(send_packet(h,out,mapping)||ack()){fputs("Companion key mapping failed.\n",stderr);goto cleanup;}
    }
    if(query(h,out,0x83,key,reply)||!matches_readback(key,desired,reply+3))goto cleanup;
    if(query(h,out,0x82,0,reply)||!list_matches(macros,reply,key,removing,newSize,nameSize))goto cleanup;
    result=0;goto cleanup;

error:
    fprintf(stderr,"USB access failed: %s\n",libusb_error_name(r));
cleanup:
    q.stopping=1;
    for(unsigned i=0;i<16;i++)if(q.slots[i])libusb_cancel_transfer(q.slots[i]);
    while(q.pending){struct timeval tv={0,10000};libusb_handle_events_timeout(ctx,&tv);}
    for(unsigned i=0;i<16;i++)if(q.slots[i])libusb_free_transfer(q.slots[i]);
    if(claimed) {
        r=libusb_release_interface(h,2);
        fprintf(stderr,"Release interface: %s\n",libusb_error_name(r));
        if(r)result=1;
    }
    if(detached) {
        r=libusb_attach_kernel_driver(h,2);
        fprintf(stderr,"Return keyboard to macOS: %s\n",libusb_error_name(r));
        if(r) {fputs("Reconnect the keyboard to restore macOS input.\n",stderr);result=1;}
    }
    if(h)libusb_close(h);
    if(config)libusb_free_config_descriptor(config);
    if(list)libusb_free_device_list(list,1);
    if(ctx)libusb_exit(ctx);
    if(!result)puts("85HA_MACRO_VERIFIED");
    return result;
}

// Single-key writer for the 85HA editor. Interrupt USB only.
// Inputs are bounded and validated before opening USB. No reset, macro or firmware commands.
#include <libusb.h>
#include "Mapping.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>

static volatile sig_atomic_t interrupted;
static void stop(int sig) { (void)sig; interrupted=1; }
static void dump(const char *label, const unsigned char *p, int n) {
    printf("%s ", label);
    for (int i=0;i<n;i++) printf("%02x",p[i]);
    putchar('\n'); fflush(stdout);
}
static int receive(libusb_device_handle *h, uint8_t ep, unsigned char reply[33]) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t);
    long long deadline=(long long)t.tv_sec*1000+t.tv_nsec/1000000+2000;
    for(;;) {
        clock_gettime(CLOCK_MONOTONIC,&t);
        long long remaining=deadline-((long long)t.tv_sec*1000+t.tv_nsec/1000000);
        if(interrupted || remaining<=0)return -1;
        int n=0;
        int r=libusb_interrupt_transfer(h,ep,reply,33,&n,(unsigned int)remaining);
        if(r || n!=33 || reply[0]!=0x54) {
            fprintf(stderr,"Read failed: %s, length %d\n",libusb_error_name(r),n);
            return -1;
        }
        dump("RX",reply,n);
        // The device may interleave live key state with configuration replies.
        if(reply[1]==0x8a)continue;
        return 0;
    }
}
static int query(libusb_device_handle *h,uint8_t out,uint8_t in,uint8_t cmd,uint8_t key,unsigned char reply[33]) {
    // Only profile read commands can use this query function.
    if(interrupted || (cmd!=0x80 && cmd!=0x81 && cmd!=0x82 && cmd!=0x83)) return -1;
    unsigned char request[33]={0x52,cmd,0};
    if(cmd==0x83) request[2]=key;
    dump("TX",request,33);
    int n=0,r=libusb_interrupt_transfer(h,out,request,33,&n,1500);
    if(r || n!=33) {fprintf(stderr,"Request failed: %s, length %d\n",libusb_error_name(r),n);return -1;}
    if(receive(h,in,reply) || reply[1]!=cmd || (cmd==0x83 && reply[2]!=key)) return -1;
    return 0;
}
int main(int argc,char **argv) {
    uint8_t key,expected[24],desired[24],name[33],macros[33];
    if(argc!=7 || strcmp(argv[1],"--write") || !parse_hex(argv[2],&key,1) || !physical_key(key) ||
       !parse_hex(argv[3],expected,24) || !(zero_mapping(expected)||mapping_valid(expected)) ||
       !parse_hex(argv[4],desired,24) || !mapping_valid(desired) ||
       !parse_hex(argv[5],name,33) || name[0]!=0x54 || name[1]!=0x80 || name[2]>28 || name[2]%2 || name[3] ||
       !parse_hex(argv[6],macros,33) || macros[0]!=0x54 || macros[1]!=0x82 || macros[32]) {
        fputs("Invalid or unsupported mapping request. Nothing was written.\n",stderr);return 2;
    }
    for(int i=2;i+3<32;i+=4){if(!macros[i])break;if(macros[i]==key){fputs("This key has a macro and is read-only.\n",stderr);return 2;}}
    if(geteuid()!=0){fputs("Administrator authorization is required for USB writing.\n",stderr);return 2;}
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
    if(matches!=1 || !in || !out)goto cleanup;
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

    unsigned char reply[33];
    if(query(h,out,in,0x80,0,reply) || memcmp(reply,name,33)) {fputs("Profile changed. Reload before saving.\n",stderr);goto cleanup;}
    if(query(h,out,in,0x82,0,reply) || memcmp(reply,macros,33)) {fputs("Macro list changed. Reload before saving.\n",stderr);goto cleanup;}
    if(query(h,out,in,0x83,key,reply) || memcmp(reply+3,expected,24)) {fputs("Key mapping changed. Reload before saving.\n",stderr);goto cleanup;}
    if(matches_readback(key,desired,reply+3)){result=0;goto cleanup;}
    unsigned char attention[33]={0x52,0x76,0xff};int written=0;
    r=libusb_interrupt_transfer(h,out,attention,33,&written,1500);
    if(r || written!=33)goto error;
    if(receive(h,in,reply) || memcmp(reply,"\x54\xe4\x08",3)) {fputs("Keyboard did not enter configuration mode.\n",stderr);goto cleanup;}
    unsigned char command[33]={0x52,0xfa,3,0x0c,0,0xaa,9,0x71,key};memcpy(command+9,desired,24);
    written=0;fputs("WRITE_ATTEMPTED\n",stderr);dump("TX",command,33);
    r=libusb_interrupt_transfer(h,out,command,33,&written,1500);
    if(r || written!=33)goto error;
    if(receive(h,in,reply) || memcmp(reply,"\x54\xe4\x08",3)){fputs("Keyboard rejected the mapping. Stopped without retrying.\n",stderr);goto cleanup;}
    if(query(h,out,in,0x83,key,reply) || !matches_readback(key,desired,reply+3)){fputs("Saved mapping did not match. Reload and check the backup.\n",stderr);goto cleanup;}
    if(query(h,out,in,0x82,0,reply) || memcmp(macros,reply,33)){fputs("Macro list differs after saving.\n",stderr);goto cleanup;}
    result=0;goto cleanup;
error:
    fprintf(stderr,"USB access failed: %s\n",libusb_error_name(r));
cleanup:
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
    if(!result)puts("85HA_VERIFIED");
    return result;
}

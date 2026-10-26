#import "AcroPrefix.h"
#import "include/AcroWorkspacePlugin.h"
#import "AcroSecureStore.h"
#import "StreamManager.h"
#import "StreamView.h"
#import "PairManager.h"
#import "CryptoManager.h"
#import <VideoToolbox/VideoToolbox.h>


@interface ASAppListParser:NSObject<NSXMLParserDelegate>
@property NSMutableArray* apps;
@property NSMutableDictionary* current;
@property NSMutableString* text;
@end
@implementation ASAppListParser
- (instancetype)init {if((self=[super init]))_apps=[NSMutableArray array];return self;}
- (void)parser:(NSXMLParser*)parser didStartElement:(NSString*)element namespaceURI:(NSString*)uri qualifiedName:(NSString*)name attributes:(NSDictionary*)attributes {
  if(_apps.count>=256){[parser abortParsing];return;}
  if([element isEqual:@"App"])_current=[NSMutableDictionary dictionary];_text=[NSMutableString string];
}
- (void)parser:(NSXMLParser*)parser foundCharacters:(NSString*)text {if(_text.length<1024)[_text appendString:text];}
- (void)parser:(NSXMLParser*)parser didEndElement:(NSString*)element namespaceURI:(NSString*)uri qualifiedName:(NSString*)name {
  if(_text.length<256){if([element isEqual:@"ID"])_current[@"id"]=_text;if([element isEqual:@"AppTitle"])_current[@"name"]=_text;}
  if([element isEqual:@"App"]){if(_current[@"id"]&&_current[@"name"])[_apps addObject:_current];_current=nil;}
}
@end

@interface AcroWorkspacePlugin()<FlutterStreamHandler,FlutterPlatformViewFactory,PairCallback,ConnectionCallbacks,NSXMLParserDelegate>
@property(nonatomic,weak) StreamView *surface;
@property(nonatomic) FlutterEventSink eventSink;
@property(nonatomic) StreamManager *stream;
@property(nonatomic) PairManager *pairOperation;
@property(nonatomic) HttpManager *pairHttp;
@property(nonatomic) NSOperationQueue *queue;
@property(nonatomic) NSString *pairHostId;
@property(nonatomic) NSTimer *timer;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) BOOL stopping;
@end
@interface AcroWorkspaceSurface:NSObject<FlutterPlatformView>
@property(nonatomic) StreamView *nativeView;
@end
@implementation AcroWorkspaceSurface
- (UIView*)view{return _nativeView;}
@end
@implementation AcroWorkspacePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  AcroWorkspacePlugin *plugin=[AcroWorkspacePlugin new];
  plugin.queue=[NSOperationQueue new];plugin.queue.maxConcurrentOperationCount=2;
  FlutterMethodChannel *channel=[FlutterMethodChannel methodChannelWithName:@"acrostella/workspace" binaryMessenger:registrar.messenger];
  [registrar addMethodCallDelegate:plugin channel:channel];
  FlutterEventChannel *events=[FlutterEventChannel eventChannelWithName:@"acrostella/workspace/events" binaryMessenger:registrar.messenger];[events setStreamHandler:plugin];
  [registrar registerViewFactory:plugin withId:@"acrostella/workspace/video"];
  [NSNotificationCenter.defaultCenter addObserver:plugin selector:@selector(suspend) name:UIApplicationDidEnterBackgroundNotification object:nil];
}
- (void)emit:(NSDictionary*)event {
  dispatch_async(dispatch_get_main_queue(),^{if(self.eventSink)self.eventSink(event);});
}
- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {_eventSink=events;return nil;}
- (FlutterError*)onCancelWithArguments:(id)arguments {_eventSink=nil;return nil;}
- (NSObject<FlutterMessageCodec>*)createArgsCodec{return FlutterStandardMessageCodec.sharedInstance;}
- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId arguments:(id)args {
  AcroWorkspaceSurface *view=[AcroWorkspaceSurface new];view.nativeView=[[StreamView alloc]initWithFrame:frame];self.surface=view.nativeView;return view;
}
- (FlutterError*)failure:(NSString*)message {return [FlutterError errorWithCode:@"workspace" message:message?:@"No se pudo completar la operación." details:nil];}
- (NSString*)certKey:(NSString*)hostId{return [@"server-" stringByAppendingString:hostId];}
- (void)stop:(void (^)(void))completion {
  if(self.stopping){if(completion)completion();return;}
  self.stopping=YES;self.generation++;
  [self.pairHttp cancel];[self.pairOperation cancel];self.pairOperation=nil;self.pairHttp=nil;
  [self.surface releaseInputs];[self.timer invalidate];self.timer=nil;
  StreamManager *current=self.stream;self.stream=nil;
  void (^finished)(void)=^{self.stopping=NO;[self emit:@{@"type":@"state",@"state":@"disconnected"}];if(completion)completion();};
  if(current)[current stopStreamWithCompletion:finished];else finished();
}
- (void)suspend {[self stop:nil];}
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSDictionary *args=[call.arguments isKindOfClass:NSDictionary.class]?call.arguments:@{};
  NSString *hostId=args[@"hostId"],*address=args[@"address"];
  if([call.method isEqual:@"capabilities"]){
    result(@{@"platform":@"iPadOS/iOS",@"integrated":@YES,
      @"h264Hardware":@(VTIsHardwareDecodeSupported(kCMVideoCodecType_H264)),
      @"hevcHardware":@(VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)),
      @"av1Hardware":@(VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1))});
  } else if([call.method isEqual:@"disconnect"]){[self stop:^{result(nil);}];
  } else if([call.method isEqual:@"keyboard"]){
    self.surface.softwareKeyboardRequested=[args[@"visible"] boolValue];[self.surface becomeFirstResponder];[self.surface reloadInputViews];result(nil);
  } else if([call.method isEqual:@"input"]){
    if(args[@"trackpad"])self.surface.trackpad=[args[@"trackpad"] boolValue];
    if(args[@"scroll"])self.surface.scrollEnabled=[args[@"scroll"] boolValue];
    if(args[@"rightClick"])self.surface.rightClickEnabled=[args[@"rightClick"] boolValue];
    if(args[@"key"])[self.surface sendSpecialKey:[args[@"key"] intValue] toggle:[args[@"toggle"] boolValue]];
    if([args[@"right"] boolValue])[self.surface sendRightClick];result(nil);
  } else if([call.method isEqual:@"pair"]){
    if(self.stream||self.pairOperation){result([self failure:@"Finaliza la sesión o el emparejamiento anterior."]);return;}
    if(![hostId isKindOfClass:NSString.class]||hostId.length>64||![address isKindOfClass:NSString.class]||address.length>256){result([self failure:@"Dirección inválida."]);return;}
    self.pairHostId=hostId;
    NSUInteger token=++self.generation;
    [self.queue addOperationWithBlock:^{
      [CryptoManager generateKeyPairUsingSSL];
      NSData *cert=[CryptoManager readCertFromFile];
      if(!cert||![CryptoManager readP12FromFile]){[self pairFailed:@"No se pudo guardar la identidad en el llavero."];return;}
      dispatch_async(dispatch_get_main_queue(),^{
        if(token!=self.generation)return;
        self.pairHttp=[[HttpManager alloc]initWithAddress:address httpsPort:0 serverCert:ASReadSecret([self certKey:hostId])];
        self.pairOperation=[[PairManager alloc]initWithManager:self.pairHttp clientCert:cert callback:self];
        [self.queue addOperation:self.pairOperation];
      });
    }];result(nil);
  } else if([call.method isEqual:@"apps"]){
    NSData *cert=ASReadSecret([self certKey:hostId?:@""]);
    if(!cert){result([self failure:@"Empareja primero este ordenador."]);return;}
    [self.queue addOperationWithBlock:^{
      HttpManager *http=[[HttpManager alloc]initWithAddress:address httpsPort:0 serverCert:cert];
      ServerInfoResponse *info=[ServerInfoResponse new];[http executeRequestSynchronously:[HttpRequest requestForResponse:info withUrlRequest:[http newServerInfoRequest:false]]];
      HttpResponse *apps=[HttpResponse new];[http executeRequestSynchronously:[HttpRequest requestForResponse:apps withUrlRequest:[http newAppListRequest]]];
      if(![info isStatusOk]||![apps isStatusOk]){dispatch_async(dispatch_get_main_queue(),^{result([self failure:info.statusMessage]);});return;}
      ASAppListParser* appParser=[ASAppListParser new];
      NSXMLParser* xml=[[NSXMLParser alloc]initWithData:apps.data];xml.shouldResolveExternalEntities=NO;xml.delegate=appParser;
      if(apps.data.length>1024*1024||![xml parse]){dispatch_async(dispatch_get_main_queue(),^{result([self failure:@"Lista de aplicaciones inválida."]);});return;}
      NSArray* list=appParser.apps;
      NSString *permission=[info getStringTag:@"Permission"];
      NSDictionary *value=@{@"apps":list,@"permission":permission?@([permission longLongValue]):NSNull.null,
        @"virtualDisplayCapable":@([[info getStringTag:@"VirtualDisplayCapable"] boolValue]),
        @"virtualDisplayReady":@([[info getStringTag:@"VirtualDisplayDriverReady"] boolValue])};
      dispatch_async(dispatch_get_main_queue(),^{result(value);});
    }];
  } else if([call.method isEqual:@"connect"]){
    if(self.stream||self.pairOperation||self.stopping){result([self failure:@"Ya hay una sesión en curso."]);return;}
    if(!self.surface){result([self failure:@"Prepara la superficie de vídeo antes de conectar."]);return;}
    NSData *cert=ASReadSecret([self certKey:hostId?:@""]);
    if(!cert){result([self failure:@"Empareja primero este ordenador."]);return;}
    NSDictionary *profile=args[@"profile"];
    int width=[profile[@"width"] intValue],height=[profile[@"height"] intValue],fps=[profile[@"fps"] intValue],bitrate=[profile[@"bitrateMbps"] intValue];
    if(width<320||height<240||width>7680||height>4320||width%2||height%2||fps<24||fps>60||bitrate<1||bitrate>150||![args[@"appId"] isKindOfClass:NSString.class]){result([self failure:@"Perfil o aplicación inválidos."]);return;}
    NSString *codec=profile[@"codec"];
    if([codec isEqual:@"av1"]&&!VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)){result([self failure:@"AV1 por hardware no está disponible en este dispositivo."]);return;}
    if([codec isEqual:@"hevc"]&&!VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)){result([self failure:@"HEVC por hardware no está disponible en este dispositivo."]);return;}
    StreamConfiguration *config=[StreamConfiguration new];config.host=address;config.httpsPort=0;config.serverCert=cert;config.appID=args[@"appId"];
    config.width=width;config.height=height;config.frameRate=fps;config.bitRate=bitrate*1000;config.audioConfiguration=AUDIO_CONFIGURATION_STEREO;
    config.supportedVideoFormats=[codec isEqual:@"av1"]?VIDEO_FORMAT_AV1_MAIN8:([codec isEqual:@"hevc"]?VIDEO_FORMAT_H265:VIDEO_FORMAT_H264);
    config.useFramePacing=[profile[@"presentation"] isEqual:@"paced"];config.virtualDisplay=[args[@"virtualDisplay"] boolValue];
    self.surface.remoteWidth=width;self.surface.remoteHeight=height;self.surface.trackpad=[profile[@"pointer"] isEqual:@"trackpad"];
    self.stream=[[StreamManager alloc]initWithConfig:config renderView:self.surface connectionCallbacks:self];[self.queue addOperation:self.stream];
    [self emit:@{@"type":@"state",@"state":@"connecting"}];result(nil);
  } else result(FlutterMethodNotImplemented);
}
- (void)startPairing:(NSString*)pin {[self emit:@{@"type":@"pairing",@"pin":pin}];}
- (void)pairSuccessful:(NSData*)cert {
  BOOL saved=ASWriteSecret([self certKey:self.pairHostId],cert);
  self.pairOperation=nil;self.pairHttp=nil;
  [self emit:@{@"type":saved?@"paired":@"error",@"message":saved?@"Ordenador emparejado":@"No se pudo guardar el certificado del servidor."}];
}
- (void)pairFailed:(NSString*)message {self.pairOperation=nil;self.pairHttp=nil;[self emit:@{@"type":@"error",@"message":message?:@"No se pudo emparejar."}];}
- (void)alreadyPaired {self.pairOperation=nil;self.pairHttp=nil;[self emit:@{@"type":@"paired"}];}
- (void)connectionStarted {
  dispatch_async(dispatch_get_main_queue(),^{
    if(!self.stream)return;self.surface.connected=YES;[self.surface becomeFirstResponder];
    [self emit:@{@"type":@"state",@"state":@"connected"}];
    [self.timer invalidate];self.timer=[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){
      if(self.stream){NSMutableDictionary *stats=[[self.stream nativeMetrics] mutableCopy];stats[@"type"]=@"metrics";[self emit:stats];}
    }];
  });
}
- (void)connectionTerminated:(int)errorCode {[self emit:@{@"type":@"error",@"message":[NSString stringWithFormat:@"La sesión terminó (%d).",errorCode]}];dispatch_async(dispatch_get_main_queue(),^{[self stop:nil];});}
- (void)stageStarting:(const char*)name {[self emit:@{@"type":@"stage",@"message":[NSString stringWithUTF8String:name]}];}
- (void)stageComplete:(const char*)name {}
- (void)stageFailed:(const char*)name withError:(int)error portTestFlags:(int)flags {[self launchFailed:[NSString stringWithFormat:@"%s (%d). Comprueba conexión, puertos y permisos de Apollo.",name,error]];}
- (void)launchFailed:(NSString*)message {[self emit:@{@"type":@"error",@"message":message?:@"No se pudo iniciar el escritorio."}];dispatch_async(dispatch_get_main_queue(),^{[self stop:nil];});}
- (void)connectionStatusUpdate:(int)status {[self emit:@{@"type":@"quality",@"status":@(status)}];}
- (void)videoContentShown {[self emit:@{@"type":@"video"}];}
- (void)setHdrMode:(bool)enabled {}
- (void)rumble:(unsigned short)c lowFreqMotor:(unsigned short)low highFreqMotor:(unsigned short)high {}
- (void)rumbleTriggers:(uint16_t)c leftTrigger:(uint16_t)left rightTrigger:(uint16_t)right {}
- (void)setMotionEventState:(uint16_t)c motionType:(uint8_t)type reportRateHz:(uint16_t)rate {}
- (void)setControllerLed:(uint16_t)c r:(uint8_t)r g:(uint8_t)g b:(uint8_t)b {}
- (void)dealloc {[NSNotificationCenter.defaultCenter removeObserver:self];}
@end

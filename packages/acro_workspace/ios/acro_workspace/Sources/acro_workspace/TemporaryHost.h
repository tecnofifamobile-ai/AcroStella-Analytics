#import "Utils.h"
@interface TemporaryHost : NSObject
@property(atomic) State state;
@property(atomic) PairState pairState;
@property(atomic) NSString *activeAddress, *currentGame, *address, *externalAddress, *localAddress, *ipv6Address, *mac, *name, *uuid;
@property(atomic) NSData *serverCert;
@property(atomic) unsigned short httpsPort;
@property(atomic) BOOL isNvidiaServerSoftware;
@property(atomic) int serverCodecModeSupport;
@end

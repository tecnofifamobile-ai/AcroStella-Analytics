#import "AcroSecureStore.h"
#import <Security/Security.h>
static NSMutableDictionary *ASQuery(NSString *account) {
  return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService:@"com.acrostella.workspace.v1",(__bridge id)kSecAttrAccount:account} mutableCopy];
}
NSData *ASReadSecret(NSString *account) {
  NSMutableDictionary *query=ASQuery(account);
  query[(__bridge id)kSecReturnData]=@YES;
  CFTypeRef result=NULL;
  OSStatus status=SecItemCopyMatching((__bridge CFDictionaryRef)query,&result);
  return status==errSecSuccess ? CFBridgingRelease(result) : nil;
}
BOOL ASWriteSecret(NSString *account,NSData *data) {
  NSMutableDictionary *query=ASQuery(account);
  NSDictionary *values=@{(__bridge id)kSecValueData:data};
  OSStatus status=SecItemUpdate((__bridge CFDictionaryRef)query,(__bridge CFDictionaryRef)values);
  if(status==errSecItemNotFound){
    query[(__bridge id)kSecValueData]=data;
    query[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    status=SecItemAdd((__bridge CFDictionaryRef)query,NULL);
  }
  return status==errSecSuccess;
}

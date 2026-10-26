#import "AcroPrefix.h"
//
//  HttpResponse.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/30/15.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "HttpResponse.h"
#import "TemporaryApp.h"


@interface ASResponseParser:NSObject<NSXMLParserDelegate>
@property NSMutableDictionary* elements;
@property NSMutableArray<NSMutableString*>* text;
@property NSInteger status;
@property NSString* message;
@end
@implementation ASResponseParser
- (instancetype)init {if((self=[super init])){_elements=[NSMutableDictionary dictionary];_text=[NSMutableArray array];}return self;}
- (void)parser:(NSXMLParser*)parser didStartElement:(NSString*)element namespaceURI:(NSString*)uri qualifiedName:(NSString*)name attributes:(NSDictionary*)attributes {
  if(_text.count>32){[parser abortParsing];return;}
  if([element isEqual:@"root"]){_status=[attributes[@"status_code"] integerValue];_message=attributes[@"status_message"]?:@"Server Error";}
  [_text addObject:[NSMutableString string]];
}
- (void)parser:(NSXMLParser*)parser foundCharacters:(NSString*)text {[_text.lastObject appendString:text];}
- (void)parser:(NSXMLParser*)parser didEndElement:(NSString*)element namespaceURI:(NSString*)uri qualifiedName:(NSString*)name {
  if(_text.count){_elements[element]=_text.lastObject;[_text removeLastObject];}
}
@end

@implementation HttpResponse {
    NSMutableDictionary* _elements;
}
@synthesize data, statusCode, statusMessage;

- (void) populateWithData:(NSData*)xml {
    self.data = xml;
    [self parseData];
}

- (NSString*) getStringTag:(NSString*)tag {
    return [_elements objectForKey:tag];
}

- (BOOL) getIntTag:(NSString *)tag value:(NSInteger*)value {
    NSString* stringVal = [self getStringTag:tag];
    if (stringVal != nil) {
        *value = [stringVal integerValue];
        return true;
    } else {
        return false;
    }
}

- (BOOL) isStatusOk {
    return self.statusCode == 200;
}

- (void) parseData {
    _elements=[NSMutableDictionary dictionary];
    if(!self.data||self.data.length>1024*1024){self.statusCode=502;self.statusMessage=@"Invalid response size";return;}
    NSString* text=[[NSString alloc]initWithData:self.data encoding:NSUTF8StringEncoding];
    if([text rangeOfString:@"<!DOCTYPE" options:NSCaseInsensitiveSearch].location!=NSNotFound ||
       [text rangeOfString:@"<!ENTITY" options:NSCaseInsensitiveSearch].location!=NSNotFound){self.statusCode=502;self.statusMessage=@"Unsupported XML declaration";return;}
    ASResponseParser* delegate=[ASResponseParser new];
    NSXMLParser* parser=[[NSXMLParser alloc]initWithData:self.data];parser.shouldResolveExternalEntities=NO;parser.delegate=delegate;
    if(![parser parse]){self.statusCode=502;self.statusMessage=@"Invalid server XML";return;}
    _elements=delegate.elements;self.statusCode=delegate.status;self.statusMessage=delegate.message;
}
@end

/**
 * Telegram Fix for iOS 9
 * Обходит проверку SSL сертификатов внутри Telegram
 * Решает проблему "нет интернета"
 * Author: Haker1928
 */

%config(Generator=MobileSubstrate)

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <dlfcn.h>

#pragma mark - Логирование

static NSString *logPath(void) {
    return @"/var/mobile/Library/Logs/TelegramFix.log";
}

static void ensureLogDir(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = @"/var/mobile/Library/Logs";
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

static void writeLog(NSString *msg) {
    ensureLogDir();
    NSDateFormatter *ts = [[NSDateFormatter alloc] init];
    [ts setDateFormat:@"HH:mm:ss.SSS"];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [ts stringFromDate:[NSDate date]], msg];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logPath()];
    if (!fh) {
        [line writeToFile:logPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

#pragma mark - Хук SecTrustEvaluate

%hookf(OSStatus, SecTrustEvaluate, SecTrustRef trust, SecTrustResultType *result) {
    static int callCount = 0;
    callCount++;
    if (callCount <= 20) {
        writeLog([NSString stringWithFormat:@"SecTrustEvaluate call #%d", callCount]);
    }
    if (result) {
        *result = kSecTrustResultProceed;
    }
    return errSecSuccess;
}

#pragma mark - Хук NSURLConnection

%hook NSURLConnection

+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host {
    writeLog([NSString stringWithFormat:@"allowsAnyHTTPSCertificateForHost: %@", host]);
    return YES;
}

%end

#pragma mark - Хук SecTrustSetPolicies

%hookf(OSStatus, SecTrustSetPolicies, SecTrustRef trust, CFTypeRef policies) {
    writeLog(@"SecTrustSetPolicies -> bypassed");
    return errSecSuccess;
}

#pragma mark - Проверка OpenSSL

static void checkOpenSSL(void) {
    const char *syms[] = {
        "SSL_set_verify", "SSL_CTX_set_verify", "SSL_get_verify_result",
        "TLS_method", "TLSv1_2_method", "SSL_CTX_new", "SSL_new", NULL
    };
    int found = 0;
    int total = 0;
    for (int i = 0; syms[i]; i++) {
        total++;
        if (dlsym(RTLD_DEFAULT, syms[i])) {
            writeLog([NSString stringWithFormat:@"  SSL sym found: %s", syms[i]]);
            found++;
        }
    }
    writeLog([NSString stringWithFormat:@"OpenSSL check: %d/%d symbols", found, total]);
}

#pragma mark - Constructor

%ctor {
    ensureLogDir();
    [@"" writeToFile:logPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
    writeLog(@"=== Telegram Fix v1.0 LOADED ===");
    writeLog([NSString stringWithFormat:@"Bundle: %@", [[NSBundle mainBundle] bundleIdentifier]]);

    checkOpenSSL();

    if (dlsym(RTLD_DEFAULT, "SecTrustEvaluate")) {
        writeLog(@"SecTrustEvaluate: HOOKED");
    } else {
        writeLog(@"SecTrustEvaluate: NOT FOUND!");
    }

    writeLog(@"=== READY ===");
}
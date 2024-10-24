@IsTest
public class Base64UrlTest {
    
    @IsTest 
    private static void encodePlus() {
        Blob input = Blob.valueOf('6~hjk');
        String b64 = EncodingUtil.base64Encode(input);
        String b64url = Base64Url.encode(input);

        System.assertEquals('AzZ+aGpr', b64);
        System.assertEquals('AzZ-aGpr', b64url);
    }

    @IsTest 
    private static void encodeSlash() {
        Blob input = Blob.valueOf('ABCD??ABC');
        String b64 = EncodingUtil.base64Encode(input);
        String b64url = Base64Url.encode(input);

        System.assertEquals('QUJDRD8/QUJD', b64);
        System.assertEquals('QUJDRD8_QUJD', b64url);
    }

    @IsTest 
    private static void encodeEquals() {
        Blob input = Blob.valueOf('ABCD');
        String b64 = EncodingUtil.base64Encode(input);
        String b64url = Base64Url.encode(input);

        System.assertEquals('QUJDRA==', b64);
        System.assertEquals('QUJDRA', b64url);
    }

}
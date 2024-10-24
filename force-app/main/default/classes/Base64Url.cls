public with sharing class Base64Url {
    
    public static String encode(Blob data) {
        String b64data = EncodingUtil.base64Encode(data);
        b64data = b64data.replaceAll('\\+', '-');
        b64data = b64data.replaceAll('/', '_');
        b64data = b64data.remove('=');
        return b64data;
    }

}
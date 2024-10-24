public with sharing class JWTHelper {
    public String alg {get;set;}
    public String iss {get;set;}
    public String sub {get;set;}
    public String aud {get;set;}
    public Long exp {get;private set;}
    public Long iat {get;private set;}
    public Map<String,String> claims {get;set;}
    public String pkcs8 {get;set;}    
    private Integer validFor {get;private set;}
    
    private static final String RS512 = 'RS512';
    
    public class JWTException extends Exception {}
    
    public JWTHelper(String alg) {
        this.alg = alg;
        this.validFor = 1800;
    }    
    
    public String issue() {
    
        String jwt = '';
        try {
            JSONGenerator header = JSON.createGenerator(false);
            header.writeStartObject();
            header.writeStringField('alg', this.alg);
            header.writeStringField('typ', 'JWT');
            header.writeEndObject();
            String encodedHeader = Base64Url.encode(Blob.valueOf(header.getAsString()));
                
            JSONGenerator body = JSON.createGenerator(false);
            body.writeStartObject();
            body.writeStringField('iss', this.iss);
            if (this.sub != null) {
                body.writeStringField('sub', this.sub);
            }
            body.writeStringField('aud', this.aud);
            Long rightNow = (dateTime.now().getTime()/1000)+1;
            body.writeNumberField('iat', rightNow);
            this.iat = rightNow;
            body.writeNumberField('exp', (rightNow + validFor));
            this.exp = validFor;
            if (claims != null) {
                for (String claim : claims.keySet()) {
                    body.writeStringField(claim, claims.get(claim));
                }
            }
            body.writeEndObject();
            
            jwt = encodedHeader + '.' + Base64Url.encode(Blob.valueOf(body.getAsString()));
            
            if ( this.alg == RS512 ) {
                Blob signature = null;
                Blob privateKey = EncodingUtil.base64Decode(pkcs8);
                signature = Crypto.sign('RSA-SHA512', Blob.valueOf(jwt), privateKey);                            
                jwt += '.' + Base64Url.encode(signature);          
            } else {
                throw new JWTException(this.alg + ' ' + Label.ERR_ALGORITHM_NOT_IMPLEMENTED);
            }
        } catch (Exception ex) {
            throw new JWTException(ex.getMessage());
        }
        
        return jwt;    
    }    
}
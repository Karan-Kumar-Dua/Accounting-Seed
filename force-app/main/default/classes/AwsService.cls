global with sharing class AwsService {

    public class AwsResultException extends Exception {}
    public class AwsServiceWrapperArgumentException extends Exception {}

    public static AwsServiceWrapper awsServiceWrapper;
    public static List < Id > recIds;
    public static APAutomationService.APAutomationActions actions;

    // Create a date for headers and the credential string
    private static Final String aws_amz_date = Datetime.now().formatGmt('YMMdd') + 'T' + Datetime.now().formatGmt('HHmmss') + 'Z';
    private static Final String aws_date_stamp = Datetime.now().formatGmt('YMMdd');

    private static Final String AWS_WRAPPER_INTIALIZATION_ERROR = Label.ERR_AWS_WRAPPER_INITIALIZATION;
    private static Final String AWS_RESPONSE_ERROR = Label.ERR_AWS_RESPONSE;
    private static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;




    //Method to send a message to AWS SQS service

    //TODO move APAUto logic to APAutomationService to keep AwsService generic
    public static AwsServiceResult sendMessageToSQSService() {

        AwsServiceResult awsResult = new AwsServiceResult();
        String aws_authorizationHeader = setAuthorizationHeader();

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(awsServiceWrapper.aws_endpoint);
        request.setMethod('POST');
        request.setHeader('Content-Type', awsServiceWrapper.aws_content_type);
        request.setHeader('Authorization', aws_authorizationHeader);
        request.setHeader('x-amz-date', aws_amz_date);
        // Set the body as a JSON object
        request.setBody(awsServiceWrapper.aws_request_parameter);
        HttpResponse response = http.send(request);

        if (response.getStatusCode() != 200) {
            awsResult.isSuccess = false;
            awsResult.error = createError(response.getBody());
        }else{
            awsResult.isSuccess = true;
        }

        return awsResult;

    }



    //Method to set authorization header
    //Refer -: https://docs.aws.amazon.com/IAM/latest/UserGuide/create-signed-request.html
    private static String setAuthorizationHeader() {
        if(AwsServiceWrapper.hasNullField()) {
            throw new AwsServiceWrapperArgumentException(AWS_WRAPPER_INTIALIZATION_ERROR);
        }
        String canonical_request = AwsService.createCanonicalRequest();
        String string_to_sign = AwsService.createTheStringToSign(canonical_request);
        String signature = AwsService.calculateTheSignature(string_to_sign);
        String authorization_header = AwsService.addSigningInfoToTheRequest(signature);
        return authorization_header;
    }

    // CREATE A CANONICAL REQUEST - Helps to ensure that the signature that you calculate 
    //                              and the signature that AWS calculates can match.
    private static String createCanonicalRequest() {
        
        // Http Method
        String httpMethod = awsServiceWrapper.aws_httpMethod;
        
        //Create canonical URI--the part of the URI from domain to query
        String canonical_uri = awsServiceWrapper.aws_endpoint.substringAfter('com'); 
        
        //Create the canonical query string.
        String canonical_querystring = EncodingUtil.urlEncode('', 'UTF-8');
        
        //Create the canonical headers.
        String canonical_headers = 'content-type:' + awsServiceWrapper.aws_content_type + '\n' + 'host:' + awsServiceWrapper.aws_host + '\n' + 'x-amz-date:' + aws_amz_date + '\n';
        
        //Create the list of signed headers. T
        String signed_headers = 'content-type;host;x-amz-date';
        
        //Create payload hash. 
        String payload_hash = hashlibSha256(awsServiceWrapper.aws_request_parameter);
        
        //Combine elements to create canonical request
        String canonical_request =
            httpMethod + '\n' +
            canonical_uri + '\n' +
            canonical_querystring + '\n' +
            canonical_headers + '\n' +
            signed_headers + '\n' +
            payload_hash;
        
        return canonical_request;
    }
    
    //Create a string to sign
    private static String createTheStringToSign(String canonical_request) {

        //This restricts the resulting signature to the specified Region and service. 
        //The string has the following format: YYYYMMDD/region/service/aws4_request.
        String credential_scope = aws_date_stamp + '/' + awsServiceWrapper.aws_region + '/' + awsServiceWrapper.aws_service_name + '/' + 'aws4_request';
        
        //Algorithm used to create the hash of the canonical request.
        String string_to_sign =
            awsServiceWrapper.aws_algorithm + '\n' +
            aws_amz_date + '\n' +
            credential_scope + '\n' +
            hashlibSha256(canonical_request);

        return string_to_sign;
    }
    
    //Calculate the signature
    private static String calculateTheSignature(String string_to_sign) {

        // Create the signing key using the function.
        Blob signing_key = getSignatureKey(awsServiceWrapper.aws_secret_key, aws_date_stamp, awsServiceWrapper.aws_region, awsServiceWrapper.aws_service_name);
        
        // Sign the string_to_sign using the signing_key
        String signature = EncodingUtil.convertToHex(Crypto.generateMac('HmacSHA256', Blob.valueof(string_to_sign), signing_key));
        return signature;
    }
    
    // Add the signature to the request
    private static String addSigningInfoToTheRequest(String signature) {
        String credential_scope = aws_date_stamp + '/' + awsServiceWrapper.aws_region + '/' + awsServiceWrapper.aws_service_name + '/' + 'aws4_request';
        String signed_headers = 'content-type;host;x-amz-date';
        // Put the signature information in a header named Authorization.
        String authorization_header = awsServiceWrapper.aws_algorithm + ' ' + 'Credential=' + awsServiceWrapper.aws_access_key + '/' + credential_scope + ', ' + 'SignedHeaders=' + signed_headers + ', ' + 'Signature=' + signature;
        return authorization_header;
    }
    
    //Method to get the signature key
    private static Blob getSignatureKey(String key, String date_stamp, String region_name, String service_name) {
        Blob kDate = sign(date_stamp, Blob.valueof('AWS4' + key));
        Blob kRegion = sign(region_name, kDate);
        Blob kService = sign(service_name, kRegion);
        Blob kSigning = sign('aws4_request', kService);
        return kSigning;
    }

    //Method to call the hash function with the required key and data.
    private static Blob sign(String data, Blob key) {
        return Crypto.generateMac('HmacSHA256', Blob.valueOf(data), key);
    }
    private static String hashlibSha256(String message) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(message)));
    }
     
    global class AwsServiceWrapper {
        public String aws_httpMethod;
        public String aws_endpoint;
        public String aws_content_type;
        public String aws_request_parameter;
        public String aws_service_name;
        public String aws_algorithm;
        public String aws_secret_key;
        public String aws_access_key;
        public String aws_host;
        public String aws_region;

        public Map<String, Object> toMap() {
            return (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(this));
        }
 
        public Boolean hasNullField() {
            for (Object curr : this.toMap().values()) {
                if (curr == null) {
                    return true;
                }
            }
            return false;
        }
    }

    //Method to parse the XML error of AWS service
    private static AwsServiceResult.AwsError createError(String responseBody) {
        
        Dom.Document doc = new Dom.Document();  
        doc.load(responseBody);  
        Dom.XMLNode rootElement = doc.getRootElement();  
        String requestId;
        String code;
        String message;
        
        for(Dom.XMLNode childElement : rootElement.getChildElements()) {
           
            if(childElement.getName() == 'RequestId') {
                requestId = childElement.getText();
            }
            for (Dom.XMLNode detailElement : childElement.getChildElements()){
                if(detailElement.getName() == 'Code') {
                    code = detailElement.getText();
                }
                if(detailElement.getName() == 'Message') {
                    message = detailElement.getText();
                }
            }    
        }
        return new AwsServiceResult.AwsError(requestId,code,message);
    }
}
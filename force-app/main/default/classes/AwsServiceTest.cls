@isTest
public with sharing class AwsServiceTest{

    public static Final String CREATE_VENDOR_JSON = '{"OrganizationId": "00D190000007ORf","Username": "abc@accountingseed.com.partsbox","BaseUrl": "https://test.salesforce.com","FSVersion": "3.179","ERPVersion": "3.69","Action": "CreateVendor","ContextId": "4qX9o_hd_p1tdvX2-pUA5-","Data": {"RecordIds": ["0011600001yoHInAAM","0013j00002zqFMqAAM","0011L00002TX8RwQAL"]}}';
    public static Final String UPDATE_VENDOR_JSON = '{"OrganizationId": "00D190000007ORf","Username": "abc@accountingseed.com.partsbox","BaseUrl": "https://test.salesforce.com","FSVersion": "3.179","ERPVersion": "3.69","Action": "UpdateVendor","ContextId": "4qX9o_hd_p1tdvX2-pUA5-","Data": {"RecordIds": ["0011600001yoHInAAM","0013j00002zqFMqAAM","0011L00002TX8RwQAL"]}}';
    public static Final String CREATE_BANK_ACCOUNT_JSON = '{"OrganizationId": "00D190000007ORf","Username": "abc@accountingseed.com.partsbox","BaseUrl": "https://test.salesforce.com","FSVersion": "3.179","ERPVersion": "3.69","Action": "CreateBankAccount","ContextId": "4qX9o_hd_p1tdvX2-pUA5-","Data": {"RecordIds": ["0011600001yoHInAAM","0013j00002zqFMqAAM","0011L00002TX8RwQAL"]}}';
    public static Final String UPDATE_BANK_ACCOUNT_JSON = '{"OrganizationId": "00D190000007ORf","Username": "abc@accountingseed.com.partsbox","BaseUrl": "https://test.salesforce.com","FSVersion": "3.179","ERPVersion": "3.69","Action": "UpdateBankAccount","ContextId": "4qX9o_hd_p1tdvX2-pUA5-","Data": {"RecordIds": ["0011600001yoHInAAM","0013j00002zqFMqAAM","0011L00002TX8RwQAL"]}}';
    public static Final String CREATE_PAYMENTS_JSON = '{"OrganizationId": "00D190000007ORf","Username": "abc@accountingseed.com.partsbox","BaseUrl": "https://test.salesforce.com","FSVersion": "3.179","ERPVersion": "3.69","Action": "CreatePayments","ContextId": "4qX9o_hd_p1tdvX2-pUA5-","Data": {"RecordIds": ["0011600001yoHInAAM","0013j00002zqFMqAAM","0011L00002TX8RwQAL"]}}';
    public static Final String CREATE_COMPANY_JSON = '{"OrganizationId": "00D190000007ORf","Username": "abc@accountingseed.com.partsbox","BaseUrl": "https://test.salesforce.com","FSVersion": "3.179","ERPVersion": "3.69","Action": "CreateCompany","ContextId": "4qX9o_hd_p1tdvX2-pUA5-","Data": {"RecordIds": ["0011600001yoHInAAM","0013j00002zqFMqAAM","0011L00002TX8RwQAL"]}}';
    public static Final String UPDATE_COMPANY_JSON = '{"OrganizationId": "00D190000007ORf","Username": "abc@accountingseed.com.partsbox","BaseUrl": "https://test.salesforce.com","FSVersion": "3.179","ERPVersion": "3.69","Action": "UpdateCompany","ContextId": "4qX9o_hd_p1tdvX2-pUA5-","Data": {"RecordIds": ["0011600001yoHInAAM","0013j00002zqFMqAAM","0011L00002TX8RwQAL"]}}';
    public static Final String ERROR_RESPONSE_JSON = '<ErrorResponse><Error><Type>Sender</Type><Code>InvalidParameterValue</Code><Message>Value (quename_nonalpha) for parameter QueueName is invalid.Must be an alphanumeric String of 1 to 80 in length.</Message></Error><RequestId>42d59b56-7407-4c4a-be0f-4c88daeea257</RequestId></ErrorResponse>';

    
    //This test method is required to have the code coverage
    @isTest
    public static void testSendMessageToSQSService() {
        AwsService.AwsServiceWrapper awsServiceWrapper = new AwsService.AwsServiceWrapper();
        awsServiceWrapper.aws_httpMethod = 'POST';
        awsServiceWrapper.aws_endpoint = 'https://sqs.us-east-2.amazonaws.com/170576735005/AP_MD_DEV.fifo';
        awsServiceWrapper.aws_content_type = 'application/x-www-form-urlencoded';
        awsServiceWrapper.aws_request_parameter = 'Action=SendMessage&MessageGroupId=122808&MessageBody=xyz';
        awsServiceWrapper.aws_service_name = 'sqs';
        awsServiceWrapper.aws_algorithm = 'AWS4-HMAC-SHA256';
        awsServiceWrapper.aws_secret_key = 'Secret-Key';
        awsServiceWrapper.aws_access_key = 'Access-Key';
        awsServiceWrapper.aws_host = 'sqs.us-east-2.amazonaws.com';
        awsServiceWrapper.aws_region = 'us-east-2';
        AwsService.awsServiceWrapper = awsServiceWrapper;
    
        Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_VENDOR_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
    
            Test.setMock(HttpCalloutMock.class, awsSuccess); 
            Boolean isSuccess = false;
            try {
                AwsService.sendMessageToSQSService();
                isSuccess = true;
            }
            catch(Exception ex) {
                isSuccess = false;
            }
            Assert.areEqual(true,isSuccess);
            
        Test.stopTest();
        }
    
     @isTest
    public static void testSendMessageToSQSServiceErrorResponse() {
        AwsService.AwsServiceWrapper awsServiceWrapper = new AwsService.AwsServiceWrapper();
        awsServiceWrapper.aws_httpMethod = 'POST';
        awsServiceWrapper.aws_endpoint = 'https://sqs.us-east-2.amazonaws.com/170576735005/AP_MD_DEV.fifo';
        awsServiceWrapper.aws_content_type = 'application/x-www-form-urlencoded';
        awsServiceWrapper.aws_request_parameter = 'Action=SendMessage&MessageGroupId=122808&MessageBody=xyz';
        awsServiceWrapper.aws_service_name = 'sqs';
        awsServiceWrapper.aws_algorithm = 'AWS4-HMAC-SHA256';
        awsServiceWrapper.aws_secret_key = 'Secret-Key';
        awsServiceWrapper.aws_access_key = 'Access-Key';
        awsServiceWrapper.aws_host = 'sqs.us-east-2.amazonaws.com';
        awsServiceWrapper.aws_region = 'us-east-2';
        AwsService.awsServiceWrapper = awsServiceWrapper;
    
        Test.startTest();
        //Setting of mock
        SingleRequestMock awsError = new SingleRequestMock(
                400,
                'InComplete',
                AwsServiceTest.ERROR_RESPONSE_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
        );
    
        Test.setMock(HttpCalloutMock.class, awsError); 
        Boolean isError = false;
        AwsServiceResult awsResult;
        try {
            awsResult = AwsService.sendMessageToSQSService();
        }
        catch(Exception e) {
            isError = true;
        }
        Assert.areEqual(false, awsResult.isSuccess);

        Test.stopTest();

        
    }

   }
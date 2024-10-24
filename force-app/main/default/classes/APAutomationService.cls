public with sharing class APAutomationService {
    public class APAutomationServiceException extends Exception {}

    private static List<Accounting_Settings__c> accountingSettings;
    private static String aws_access_key {get;set;}
    private static String aws_secret_key {get;set;}
    private static String aws_host {get;set;}
    private static String aws_endpoint {get;set;}
    private static String aws_region {get;set;}
    private static String baseURL {get;set;}
    private static Boolean isSandbox = false;
    private static String aws_request_parameters = 'Action=SendMessage&MessageGroupId=';
    public static List <Id> recIds;

    private static Final String aws_content_type = 'application/x-www-form-urlencoded';
    private static Final String aws_service = 'execute-api';
    private static Final String aws_algorithm = 'AWS4-HMAC-SHA256';
    private static Final Boolean isERPEnabled = AccountingSettingsHandler.isERPEnabled();
    private static Final String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;                                                                                                                                                                                                         
    private static Final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static Final String DEFAULT_PACKAGE_VERSION = '3.69';
    private static Final String ERP_DEFAULT_PACKAGE_VERSION = '3.179';
    private static Final String AWS_RESPONSE_ERROR = Label.ERR_AWS_RESPONSE;
    private static Final String SANDBOX_OVERRIDE_CUSTOM_SETTING ='Payment_Services_Sandbox_Mode';
    private static Final String DEV_OVERRIDE_CUSTOM_SETTING ='Payment_Services_Dev_Mode';
    private static Final String PRODUCTION_BASE_URL ='https://login.salesforce.com';
    private static Final String DEV_TEST_BASE_URL ='https://test.salesforce.com';


    private static Final String MASTER_DATA_STATUS_PROCESSING = 'Processing';
    private static Final String MASTER_DATA_STATUS_DENIED = 'Denied';
    private static Final String SUBMIT_APPLICATION_STATUS_IN_PROGRESS ='In Progress';
    private static Final String SUBMIT_APPLICATION_STATUS_DECLINED ='Declined';
    private static Final String PAYMENTS_STATUS_IN_PROGRESS ='Pending';
    private static Final String PAYMENTS_STATUS_DECLINED ='Needs Attention';

    private static Final String AP_AUTOMATION_HUB_USER_ERROR = Label.ERR_AP_AUTOMATION_HUB_USER;

    //Enums for all the AP automation Actions
    public enum APAutomationActions {
        CREATE_BANK_ACCOUNT,
        UPDATE_BANK_ACCOUNT,
        CREATE_VENDOR,
        UPDATE_VENDOR,
        CREATE_COMPANY,
        UPDATE_COMPANY,
        SUBMIT_APPLICATION,
        CREATE_PAYMENTS
    }

    private static Final Map<APAutomationActions, String> mapOfActionAndValue = new Map<APAutomationActions, String>{
        APAutomationActions.CREATE_BANK_ACCOUNT =>'CreateBankAccount' , 
        APAutomationActions.UPDATE_BANK_ACCOUNT =>'UpdateBankAccount',
        APAutomationActions.CREATE_VENDOR =>'CreateVendor' ,
        APAutomationActions.UPDATE_VENDOR =>'UpdateVendor' ,
        APAutomationActions.CREATE_COMPANY =>'CreateCompany' ,
        APAutomationActions.UPDATE_COMPANY =>'UpdateCompany' ,
        APAutomationActions.SUBMIT_APPLICATION =>'SubmitNewApplication' ,
        APAutomationActions.CREATE_PAYMENTS =>'CreatePayments' 
    };


    //method called from LWC and triggers.  Call initilizie function first before future method 
    @AuraEnabled
    public static void postMessage(List<Id> recordIds, String action) {
        try{
            intialize(APAutomationActions.valueOf(action), recordIds);
            if(System.Trigger.isExecuting){
                PostMessageQueueable postMessageQueueable = new PostMessageQueueable(recordIds, action);
                System.enqueueJob(postMessageQueueable);
            }else{
                postMessageToSQS(recordIds, action);
            }  
        }
        catch(Exception e) {
            throw new APAutomationServiceException(e.getMessage() );
        }
        
    }

    public class PostMessageQueueable implements Queueable, Database.AllowsCallouts {
        List<Id> recordIds;
        String action;
        public PostMessageQueueable(List<Id> recordIds, String action) {
            this.recordIds = recordIds;
            this.action = action;
        }
        public void execute(QueueableContext qc) {
            //reinitialize in queueable context
            intialize(APAutomationActions.valueOf(action), recordIds);
            postMessageToSQS(recordIds, action);
        }
    }

      //Method to intialize parameters related to AWS service
      private static void intialize(APAutomationActions action, List <Id> recordIds) {
         
        if(FinancialSuiteUtils.isOrganizationInstanceSandbox){
            baseURL = DEV_TEST_BASE_URL;
            isSandbox = true;
        }else{
            baseURL = PRODUCTION_BASE_URL;
        }
        External_Settings__mdt sqsEndpoint = getSQSEndpoint(action);
              
        aws_access_key = sqsEndpoint.Value_1__c;
        aws_secret_key = sqsEndpoint.Value_2__c;
        aws_endpoint   = sqsEndpoint.Value_5__c;
        aws_host       = aws_endpoint.substringBetween('//','/'); 
        aws_region     = sqsEndpoint.Value_3__c;
        accountingSettings = DomainUtils.getAccountingSettings();
        recIds = recordIds;
       
        if(accountingSettings.size() < 1  || String.isBlank(accountingSettings[0].Hub_UserName__c)) {
            throw new APAutomationServiceException(AP_AUTOMATION_HUB_USER_ERROR);
        }
    }

    //Method to create a payload in AWS SQS service
    private static void postMessageToSQS(List<Id> recordIds, String action) {
        try {
            //Create request parameter with Message Group Id = Organization Id
            Map<String, Object> mBody = new Map<String, Object>();
            mBody.put('MessageGroupId', UserInfo.getOrganizationId());
            mBody.put('MessageBody', constructMessage(APAutomationActions.valueOf(action), recordIds));
            aws_request_parameters = JSON.serialize(mBody);
            //Construct wrapper to call AWS service
            AwsService.AwsServiceWrapper awsServiceWrapper = new AwsService.AwsServiceWrapper();
            awsServiceWrapper.aws_httpMethod = 'POST';
            awsServiceWrapper.aws_endpoint = aws_endpoint;
            awsServiceWrapper.aws_content_type = aws_content_type;
            awsServiceWrapper.aws_request_parameter = aws_request_parameters;
            awsServiceWrapper.aws_service_name = aws_service;
            awsServiceWrapper.aws_algorithm = aws_algorithm;
            awsServiceWrapper.aws_secret_key = aws_secret_key;
            awsServiceWrapper.aws_access_key = aws_access_key;
            awsServiceWrapper.aws_host = aws_host;
            awsServiceWrapper.aws_region = aws_region;
            
            AwsService.awsServiceWrapper = awsServiceWrapper;
            AwsService.recIds = recordIds;
            AwsService.actions = APAutomationActions.valueOf(action);
          
            //Call AWS service to send the payload
            AwsServiceResult awsResult = AwsService.sendMessageToSQSService();
            
            updateFieldValues(awsResult.isSuccess, APAutomationActions.valueOf(action));

            // Parse the JSON response if 
            if (!awsResult.isSuccess) {
                throw new AwsService.AwsResultException(String.format(
                            AWS_RESPONSE_ERROR,
                            new List<String>{
                                awsResult.error.requestId,
                                awsResult.error.message
                }));
            }

            
        }
        catch(Exception e) {
            throw new APAutomationServiceException(e.getMessage() + ' Line : ' + e.getLineNumber());
        }
    }

    private static External_Settings__mdt getSQSEndpoint(APAutomationActions action){
        External_Settings__mdt sqsEndpoint;
        Config_Override__c configDevOverride = Config_Override__c.getInstance(DEV_OVERRIDE_CUSTOM_SETTING);
        Config_Override__c configTestOverride = Config_Override__c.getInstance(SANDBOX_OVERRIDE_CUSTOM_SETTING);
        
        if(configDevOverride != null && configDevOverride.Active__c){
            sqsEndpoint = (action == APAutomationActions.CREATE_PAYMENTS) ? 
                External_Settings__mdt.getInstance('Payment_Services_TRXN_Dev') : 
                External_Settings__mdt.getInstance('Payment_Services_MD_Dev');
        }else if((configTestOverride != null && configTestOverride.Active__c) || isSandbox){
            sqsEndpoint = (action == APAutomationActions.CREATE_PAYMENTS) ? 
                External_Settings__mdt.getInstance('Payment_Services_TRXN_Test') : 
                External_Settings__mdt.getInstance('Payment_Services_MD_Test');
        }else{
            sqsEndpoint = (action == APAutomationActions.CREATE_PAYMENTS) ? 
                External_Settings__mdt.getInstance('Payment_Services_TRXN_Prod') : 
                External_Settings__mdt.getInstance('Payment_Services_MD_Prod');
        }
       
        return sqsEndpoint;
    }

    //Method to construct the payload 
    private static Map<String,Object> constructMessage(APAutomationActions action, List<String> recIds) {
        Map<String, Object> mapToConstructJson = new Map<String, Object>();
        
        mapToConstructJson.put('OrganizationId',UserInfo.getOrganizationId());
        mapToConstructJson.put('Username',accountingSettings[0].Hub_UserName__c);
        mapToConstructJson.put('BaseUrl',baseURL);
        mapToConstructJson.put('FSVersion',getPackageVersion(PACKAGE_QUALIFIER));
        
        if(isERPEnabled) {
            mapToConstructJson.put('ERPVersion',getPackageVersion(ERP_PACKAGE_QUALIFIER));
        }

        mapToConstructJson.put('Action',mapOfActionAndValue.get(action));
        //Get the identifier for this request, which is universally unique
        mapToConstructJson.put('ContextId.',Request.getCurrent().getRequestId());

        Map<String, List<String>> mapOfDataAndrecId  = new Map<String, List<String>>();
        mapOfDataAndrecId.put('RecordIds',recIds);
        mapToConstructJson.put('Data',mapOfDataAndrecId);
        mapToConstructJson.put('StateCountryFullName',isStateAndCountryEnabled());
        return mapToConstructJson;
    }

    //Method to get the package version
    private static String getPackageVersion(String package_qualifier) {
            boolean packaged = false;
            try {
                UserInfo.isCurrentUserLicensed(package_qualifier);
                packaged = true;
            } catch(System.TypeException e){
                packaged = false;
            }

            String vName = package_qualifier.contains('ERP') ? DEFAULT_PACKAGE_VERSION : ERP_DEFAULT_PACKAGE_VERSION;
            if (packaged && !Test.isRunningTest()) {
                Version v = System.requestVersion();
                if (v != null) {
                    vName = v.major() + '.' + v.minor();
                }
            }
            return vName;
    }

    public static void updateFieldValues(boolean isSuccess, APAutomationService.APAutomationActions action) {

        string status;
        String statusField = 'Payment_Services_Enrollment_Status__c';
        
        if(action == APAutomationService.APAutomationActions.CREATE_VENDOR || action == APAutomationService.APAutomationActions.CREATE_BANK_ACCOUNT){
            status = isSuccess ? MASTER_DATA_STATUS_PROCESSING : MASTER_DATA_STATUS_DENIED;
        } else if(action == APAutomationService.APAutomationActions.SUBMIT_APPLICATION){
            status = isSuccess ? SUBMIT_APPLICATION_STATUS_IN_PROGRESS : SUBMIT_APPLICATION_STATUS_DECLINED;
        } else if(action == APAutomationService.APAutomationActions.CREATE_PAYMENTS){
            statusField = 'Payment_Service_Status__c';
            status = isSuccess ? PAYMENTS_STATUS_IN_PROGRESS : PAYMENTS_STATUS_DECLINED;
        } else{
            //if it's not a create action then return and do not update the status on triggering records
            return;
        }

        List <sObject> recordsToUpdate = new List <sObject> ();
        List < String > queryFields = new List < String > {
            'Id',
            statusField
        };

        SOQLBuilder theQuery = new SOQLBuilder(recIds[0].getSObjectType());
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition('ID IN: recIds');

        for (sObject sobjRec: (List < sObject > ) Database.query(theQuery.toSOQL())) {
            sobjRec.put(statusField, status); 
            recordsToUpdate.add(sobjRec);
        }

        Schema.DescribeSObjectResult objResult = recIds[0].getSObjectType().getDescribe();
        if (objResult.isUpdateable()) {
            Map < String, Schema.SObjectField > FsMap = objResult.fields.getMap();
            Schema.sobjectField fld = FsMap.get(PACKAGE_QUALIFIER + statusField.toLowerCase());
            Schema.DescribeFieldResult dfr = fld.getDescribe();
            checkFieldAndUpdate(dfr, recordsToUpdate, objResult);
        } else {
            showObjectErrors(objResult);
        }
    }

    private static void checkFieldAndUpdate(Schema.DescribeFieldResult dfr, List<sObject> records, Schema.DescribeSObjectResult objResult) {
        if (dfr.isUpdateable()) {
            //SFDCSecurityUtils requires a strictly typed list in order to determine the type
            String listType = 'List<' + records[0].getSObjectType() + '>';
            List<SObject> castRecords = (List<SObject>)Type.forName(listType).newInstance();
            //cast the records to the typed list
            castRecords.addAll(records);
            //check CRUD and Update
            SFDCSecurityUtils.updateCheckCRUDAndFLS(castRecords, new List<String>(), false);
        } else {
            showFieldErrors(objResult, dfr);
        }
    }

    private static void showFieldErrors(Schema.DescribeSObjectResult objResult, Schema.DescribeFieldResult dfr) {
        String result = String.format(
            Label.ERR_NEED_TO_SET_FLS_PERMISSION,
            new List < String > {
                Label.COMMON_EDIT_ACCESS,
                objResult.getLabel()
            });

        result = result + dfr.getLabel();

        throw new AwsService.AwsResultException(result);
    }

    private static void showObjectErrors(Schema.DescribeSObjectResult objResult) {
        throw new AwsService.AwsResultException(String.format(
            Label.ERR_PLEASE_SET_PERMISSION_SET,
            new List < String > {
                Label.COMMON_EDIT_ACCESS,
                objResult.getLabel()
            }
        ));
    }

    public static Boolean isStateAndCountryEnabled(){
        Schema.DescribeSObjectResult orgDescribe = Schema.getGlobalDescribe().get('Organization').getDescribe();
        // Check if the CountryCode field exists
        return orgDescribe.fields.getMap().containsKey('CountryCode');
    }

}
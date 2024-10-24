public with sharing class VirtualCardService {

    public class VirtualCardServiceException extends Exception{}

    private final String METHOD_PUT = 'PUT';
    private final String BLOCK_RETURN_ROUTE = '/payments/api/v1/virtual-card/return';
    private final string AP_AUTOMATION_HUB_USER_ERROR = Label.ERR_AP_AUTOMATION_HUB_USER;
    private final string BLOCKED = Label.COMMON_BLOCKED;
    private static Final String SANDBOX_OVERRIDE_CUSTOM_SETTING ='Payment_Services_Sandbox_Mode';
    private static Final String DEV_OVERRIDE_CUSTOM_SETTING ='Payment_Services_Dev_Mode';
    private static Final String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    private static Final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static Final String DEFAULT_PACKAGE_VERSION = '3.179';
    private static Final String ERP_DEFAULT_PACKAGE_VERSION = '3.69';
    private static Final Boolean isERPEnabled = AccountingSettingsHandler.isERPEnabled();


    public VirtualCardService(){
        if(String.isBlank(accountingSettings.Hub_UserName__c)) {
            throw new VirtualCardServiceException(AP_AUTOMATION_HUB_USER_ERROR);
        }
    }

    public class BlockAndReturnFunds implements Queueable, Database.AllowsCallouts {
        List<Id> paymentMethodIds;
        public BlockAndReturnFunds(List<Id> paymentMethodIds){
            this.paymentMethodIds = paymentMethodIds;
        }
        public void execute(QueueableContext context) {
            VirtualCardService vcs = new VirtualCardService();
            vcs.blockAndReturnFunds(this.paymentMethodIds);
        }

    }


    public Map<Id, HttpResponse> blockAndReturnFunds(List<Id> paymentMethodIds){
        Map<Id, HttpResponse> mResponses = new Map<Id, HttpResponse>();
        List<AcctSeed__Payment_Method__c> paymentMethods = this.fetchPaymentMethods(paymentMethodIds);

        for(AcctSeed__Payment_Method__c pm : paymentMethods){
            HttpResponse iResponse = this.doCallout(this.METHOD_PUT, this.BLOCK_RETURN_ROUTE, this.generateBlockAndReturnFundsPayload(pm));
            mResponses.put(pm.Id, iResponse);
            if(iResponse.getStatusCode() == 200 || iResponse.getStatusCode() == 201){
                pm.Status__c = BLOCKED;
                pm.Available_Balance__c = 0;
            }
        }

        SFDCSecurityUtils.updateProxy(paymentMethods);

        return mResponses;
    }

    private string generateBlockAndReturnFundsPayload(AcctSeed__Payment_Method__c paymentMethod){
        Map<String, String> mProps = new Map<String, String>{
                'OrganizationId' => UserInfo.getOrganizationId(),
                'BaseUrl' => URL.getOrgDomainURL().toExternalForm(),
                'Username' => this.accountingSettings.Hub_Username__c,
                'ContextId' => Request.getCurrent().getRequestId(),
                'COMPANY' => this.accountingSettings.Default_Payment_Services_Ledger__r.Payment_Services_Company_Code__c,
                'VirtualCardId' => paymentMethod.AP_External_Id__c,
                'PaymentMethodId' => paymentMethod.Id,
                'FSVersion' => getPackageVersion(PACKAGE_QUALIFIER),
                'ERPVersion' => getPackageVersion(ERP_PACKAGE_QUALIFIER)
        };

        return JSON.serialize(mProps);
    }

    private HttpResponse doCallout(String method, String route, String payload){

        External_Settings__mdt api = getAPIEndpoint();

        HttpRequest req = new HttpRequest();

        req.setMethod('POST');
        req.setEndpoint(api.Value_5__c + route);
        req.setHeader('client_id', api.Value_1__c);
        req.setHeader('client_secret',api.Value_2__c);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60000);
        req.setBody(payload);

        Http h = new Http();
        HttpResponse resp;

        resp = h.send(req);

        return resp;
    }

    private List<AcctSeed__Payment_Method__c> fetchPaymentMethods(List<Id> paymentMethodIds){
        SOQLBuilder soql = new SOQLBuilder(AcctSeed__Payment_Method__c.getSObjectType());
        List<Schema.SObjectField> sObjectFields = new List<Schema.SObjectField>{
                AcctSeed__Payment_Method__c.Id,
                AcctSeed__Payment_Method__c.External_Id__c,
                AcctSeed__Payment_Method__c.AP_External_Id__c
        };
        soql.selectFields(sObjectFields);
        soql.setCondition('Id IN :paymentMethodIds');
        return Database.query(soql.toSOQL());
    }

    private AcctSeed__Accounting_Settings__c accountingSettings{
        get {
            if(accountingSettings == null){
                SOQLBuilder soql = new SOQLBuilder(AcctSeed__Accounting_Settings__c.getSObjectType());
                List<Schema.SObjectField> sObjectFields = new List<Schema.SObjectField>{
                        AcctSeed__Accounting_Settings__c.Id,
                        AcctSeed__Accounting_Settings__c.Hub_Username__c
                };
                soql.selectFields(sObjectFields);
                List<String> fieldPaths = new List<String>{
                        'Default_Payment_Services_Ledger__r.Payment_Services_Company_Code__c'
                };
                soql.selectFields(fieldPaths);
                soql.addOrdering(AcctSeed__Accounting_Settings__c.CreatedDate, SOQLBuilder.SortOrder.DESCENDING);
                soql.setLimit(1);
                accountingSettings = Database.query(soql.toSOQL());
            }
            return accountingSettings;
        }
        set;
    }

    private static External_Settings__mdt getAPIEndpoint(){
        External_Settings__mdt apiEndpoint;
        Config_Override__c configDevOverride = Config_Override__c.getInstance(DEV_OVERRIDE_CUSTOM_SETTING);
        Config_Override__c configTestOverride = Config_Override__c.getInstance(SANDBOX_OVERRIDE_CUSTOM_SETTING);

        if(configDevOverride != null && configDevOverride.Active__c){
            apiEndpoint = External_Settings__mdt.getInstance('Payments_API_DEV');
        }else if(configTestOverride != null && configTestOverride.Active__c){
            apiEndpoint = External_Settings__mdt.getInstance('Payments_API_TEST');
        }else{
            apiEndpoint = External_Settings__mdt.getInstance('Payments_API_PROD');
        }

        return apiEndpoint;
    }

    private static String getPackageVersion(String package_qualifier) {
        boolean packaged = false;
        try {
            UserInfo.isCurrentUserLicensed(package_qualifier);
            packaged = true;
        } catch(System.TypeException e){
            packaged = false;
        }

        String vName = !package_qualifier.contains('ERP') ? DEFAULT_PACKAGE_VERSION : ERP_DEFAULT_PACKAGE_VERSION;
        if (packaged && !Test.isRunningTest()) {
            Version v = System.requestVersion();
            if (v != null) {
                vName = v.major() + '.' + v.minor();
            }
        }
        return vName;
    }
}
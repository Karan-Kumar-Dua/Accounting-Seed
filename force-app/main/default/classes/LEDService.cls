public with sharing class LEDService {
    @TestVisible
    private static Boolean isSkipCallout = Test.isRunningTest();

    public static final String HOST = GlobalVariables.ledSettings.Value_1__c;
    public static final String PATH = GlobalVariables.ledSettings.Value_2__c;
    public static final String CLIENT_ID = GlobalVariables.ledSettings.Value_3__c;
    public static final String CLIENT_SECRET = GlobalVariables.ledSettings.Value_4__c;

    private static final Integer SITE_LICENSE_VALUE = -1;


    public static Map<String, Object> sendData() {
        return sendData(TriggerOperation.AFTER_UPDATE);
    }

    public static Map<String, Object> sendData(TriggerOperation operation) {
        return sendData(operation, null);
    }

    public static Map<String, Object> sendData(TriggerOperation operation, List<Accounting_Settings__c> accountingSettings) {
        Map<String, Object> payload = new Map<String, Object>{
                'Organization' => fetchOrganization(),
                'TriggerContext' => operation != null ? operation.name() : null
        };
        Map<String, Object> accountSettingsPayload = new Map<String, Object>(payload);
        accountSettingsPayload.putAll(fetchSettings(accountingSettings));

        Map<String, Object> usersPayload = new Map<String, Object>(payload);
        usersPayload.putAll(fetchUsers());

        Map<String, Object> result = new Map<String, Object>();
        result.put('accountSettings', sendData(
                HOST + PATH,
                new Map<String, String>{
                        'client_id' => CLIENT_ID,
                        'client_secret' => CLIENT_SECRET,
                        'Content-Type' => 'application/json'
                },
                JSON.serialize(accountSettingsPayload)
        ));
        result.put('users', sendData(
                HOST + PATH,
                new Map<String, String>{
                        'client_id' => CLIENT_ID,
                        'client_secret' => CLIENT_SECRET,
                        'Content-Type' => 'application/json'
                },
                JSON.serialize(usersPayload)
        ));

        return result;
    }

    public static Map<String, Object> fetchUsers() {
        List<PackageLicense> licenses = DomainUtils.licensesByPackagePrefixes(new Set<String>{'AcctSeed'});
        /*List<User> users = !licenses.isEmpty() && licenses[0].AllowedLicenses != SITE_LICENSE_VALUE
                ? DomainUtils.fetchUsersByPackageLicenseIds(new Set<String>{'AcctSeed', 'AcctSeedERP', 'AcctSeedExt'})
                : DomainUtils.fetchAllUsers();*/
        List<User> users = !licenses.isEmpty() && licenses[0].AllowedLicenses != SITE_LICENSE_VALUE
        ? DomainUtils.fetchUsersByPackageLicenseIds(new Set<String>{'AcctSeed', 'AcctSeedERP', 'AcctSeedExt'})
        : new List<User>();

        List<Map<String, Object>> records = new List<Map<String, Object>>();
        for (User userItem : users) {
            records.add(new Map<String, Object>{
                    'Id' => userItem.Id,
                    'AccountId' => userItem.AccountId,
                    'FirstName' => userItem.FirstName,
                    'LastName' => userItem.LastName,
                    'Email' => userItem.Email,
                    'Username' => userItem.Username,
                    'IsActive' => userItem.IsActive
            });
        }
        return new Map<String, Object>{
                'SObjectType' => 'User',
                'Records' => records
        };
    }

    public static Map<String, Object> fetchSettings(List<Accounting_Settings__c> accountingSettings) {
        Accounting_Settings__c accountingSetting = accountingSettings != null && !accountingSettings.isEmpty()
                ? accountingSettings[0]
                : AccountingSettingsHandler.getAccountingSettings();
        return new Map<String, Object>{
                'SObjectType' => 'AcctSeed__Accounting_Settings__c',
                'Records' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'Id' => accountingSetting.Id,
                        'AcctSeed__Inventory_Valuation_Method__c' => accountingSetting.Inventory_Valuation_Method__c,
                        'AcctSeed__Post_Settings__c' => accountingSetting.Post_Settings__c,
                        'AcctSeed__Ledger_Limit__c' => accountingSetting.Ledger_Limit__c,
                        'AcctSeed__Enable_Multi_Currency__c' => accountingSetting.Enable_Multi_Currency__c,
                        'AcctSeed__Enable_Product_Costing__c' => accountingSetting.Enable_Product_Costing__c
                    }
                }
        };
    }

    public static Map<String, Object> fetchOrganization() {
        Organization org = DomainUtils.fetchOrganization();
        return new Map<String, Object>{
                'Id' => org.Id,
                'IsSandbox' => org.IsSandbox,
                'OrganizationType' => org.OrganizationType,
                'LanguageLocaleKey' => org.LanguageLocaleKey,
                'InstanceName' => org.InstanceName,
                'TimeZoneSidKey' => org.TimeZoneSidKey,
                'IsOrgMultiCurrencyEnabled' => UserInfo.isMultiCurrencyOrganization()
        };
    }

    public static Map<String, Object> sendData(String endpoint, Map<String, String> headers, String payload) {
        HttpResponse response = isSkipCallout
                ? new HttpResponse()
                : callOut(endpoint, 'POST', headers, payload);
        return new Map<String, Object>{
                'status' => response.getStatus()
        };
    }
    public static HttpResponse callOut(String endpoint, String method, Map<String, String> headers, String body) {
        Http h = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod(method);
        for (String key : headers != null ? headers.keySet() : new Set<String>()) {
            if (String.isNotBlank(headers.get(key))) {
                request.setHeader(key, headers.get(key));
            }
        }
        if (String.isNotBlank(body)) {
            request.setBody(body);
        }
        request.setTimeout(120000);

        return h.send(request);
    }
}
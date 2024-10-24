public with sharing class AccountingHomeHelper {
    
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String ERPPACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    public static final Boolean isERPEnabled = AccountingSettingsHandler.isERPEnabled();
    public static final Boolean isWOEnabled = AccountingSettingsHandler.isWOEnabled();
    public static final Boolean isAvaVATReportingEnabled = AccountingSettingsHandler.isAvaVATReportingEnabled();
    public static final Boolean isFSLExtEnabled = AccountingSettingsHandler.isFSLExtensionEnabled();

    private static final Set<String> erpObjectApiNames = new Set<String>{
        'Warehouse__c', 'Inventory_Balance__c', 'Purchase_Order__c', 'Purchase_Price__c', 'Sales_Order__c'
    };

    /**
     * Returns this packages version number as major.minor.
     * Salesforce does not expose the patch version number.
     */
    @AuraEnabled (cacheable = true)
    public static String getPackageVersion() {
        try {
            String vName;
            if (isPackaged() || Test.isRunningTest()) {
                Version v = System.requestVersion();
                if (v != null) {
                    vName = v.major() + '.' + v.minor();
                }
            }
            else {
                vName = 'Unpackaged';
            }
            return vName;
        } 
        catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Returns the current User Organisation Id.
     */
    @AuraEnabled (cacheable = true)
    public static String getOrgId() {
        return UserInfo.getOrganizationId();
    }

    /**
     * Returns the name of the last accounting period which bounds today's date.
     */
    @AuraEnabled (cacheable = true)
    public static String getCurrentPeriod() {
        try {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance()
                .getAccountingPeriodByDate(System.today());
            return currentPeriod?.Name;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Returns the name of the last closed period and 
     * a boolean flag to signify an open period exists
     * between the current period and last closed period.
     */
    @AuraEnabled (cacheable = true)
    public static LastClosedPeriodInfo getLastClosedPeriod() {
        try {
            Date today = System.today();
            AccountingPeriodHandler handler = AccountingPeriodHandler.getInstance();
            
            // get the last closed period or null if none exist
            Accounting_Period__c lastClosedPeriod = handler.getLastClosedOrArchivedAccountingPeriod();

            if (lastClosedPeriod == null) {
                return null;
            }

            // get period after the last closed period
            Accounting_Period__c firstOpenPeriod = handler.getNextAccountingPeriod(lastClosedPeriod);
            // means there is not more than one open period between current period and last closed period
            //      closed, open, current => isCurrent = false
            //      closed, current => isCurrent = true
            Boolean isCurrent = today <= firstOpenPeriod.End_Date__c;

            return new LastClosedPeriodInfo(lastClosedPeriod, isCurrent);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(Cacheable = true)
    public static Map<String, Object> retrieveAHConfigurations(List<String> sobjectApiNames) {
        if (isERPEnabled) {
            for (String objectApiName : erpObjectApiNames) {
                sobjectApiNames.add(ERPPACKAGE_QUALIFIER + objectApiName);
            }
        }
        if (isWOEnabled) {
            sobjectApiNames.add('WorkOrder');
        }

        return new Map<String, Object>{
                'packages' => new Map<String, Object> {
                    'erp' => isERPEnabled,
                    'fsl'  => isFSLExtEnabled,
                    'ava' => isAvaVATReportingEnabled
                },
                'sobjectDetails' => retrieveSObjectDetails(sobjectApiNames),
                'templateParts' => new Map<String, Object>{
                    'PACKAGE_QUALIFIER' => PACKAGE_QUALIFIER,
                    'ERP_QUALIFIER' => ERPPACKAGE_QUALIFIER,
                    'ACCOUNTING_DASHBOARD' => getAccountingDashboard()
                }
        };
    }

    private static Boolean isPackaged() {
        boolean packaged;
        try {
            UserInfo.isCurrentUserLicensed(GlobalVariables.PACKAGE_NAME);
            packaged = true;
        } catch(System.TypeException e){
            packaged = false;
        }
        return packaged;
    }

    private static Map<String, Object> retrieveSObjectDetails(List<String> sobjectApiNames) {
        Map<String, Object> sobjectDetailsBySObjectApiNames = new Map<String, Object>();
        List<DescribeSObjectResult> soDescribes = Schema.describeSObjects(sobjectApiNames);

        for (Schema.DescribeSObjectResult soDescribe : soDescribes) {
            if (soDescribe != null) {
                sobjectDetailsBySObjectApiNames.put(soDescribe.getName().toLowerCase(), new Map<String, Object>{
                    'labelPlural' => soDescribe.getLabelPlural(),
                    'accessible' => soDescribe.isAccessible()
                });
            }
        }

        return sobjectDetailsBySObjectApiNames;
    }

    private static String getAccountingDashboard() {
        try {
            List<Dashboard> dashboards = DomainUtils.getDashboardByName(
                new Set<String>{'Accounting'}, GlobalVariables.PACKAGE_NAME
            );
            if (!dashboards.isEmpty()) {
                return dashboards[0].Id;
            }
            return null;
        }
        catch (Exception ex) {
            return null;
        }
    }

    public with sharing class LastClosedPeriodInfo {
        @AuraEnabled
        public String period;
        @AuraEnabled
        public Boolean isCurrent;

        public LastClosedPeriodInfo(Accounting_Period__c period, Boolean isCurrent) {
            this.period = period?.Name;
            this.isCurrent = isCurrent;
        }
    }

}
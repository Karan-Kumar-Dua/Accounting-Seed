public with sharing class TimeCardNewControllerExt {

    private ApexPages.StandardController controller;

    public Time_Card__c timeCard {get; private set;}
    public Boolean isEmployeeError {get; set;}
    public Boolean isPeriodError {get; set;}
    public Boolean isLedgerError {get; set;}
    public List<SelectOption> allLedgersSelectOptions {get; private set;}

    //Constructor   
    public TimeCardNewControllerExt(ApexPages.StandardController controller) {
        try {
            this.controller = controller;
            timeCard = (Time_Card__c) controller.getRecord();

            //Set defaults for new records
            timeCard.Employee__c = UserInfo.getUserId();
            Ledger__c defaultLedger = LedgerHandler.getInstanceWithSharing().getLedgerById(LedgerHandler.getLedgerId());
            if (defaultLedger != NULL) {
                timeCard.Ledger__c = defaultLedger.Id;
            }
            else if (!LedgerHandler.getInstanceWithSharing().getTransactionalLedgers().isEmpty()) {
                timeCard.Ledger__c = LedgerHandler.getInstanceWithSharing().getTransactionalLedgers().get(0).Id;
            }
            this.allLedgersSelectOptions = LedgerHandler.getInstanceWithSharing().getTransactionalLedgerSelectOptions();
            isPeriodError = false;
            isEmployeeError = false;
            isLedgerError = false;
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
    }

    private List<Time_Card__c> queryTimeCards(String employeeId, String timeCardPeriodStatus, String ledgerId) {
        List<String> queryFields = new List<String>{
            'Id', 'Time_Card_Period__c'
        };

        String ledgerCondition = '';
        if (LedgerHandler.isLedgerEqualLegacyLedger(ledgerId)) {
            ledgerCondition = 'AND (Ledger__c = :ledgerId OR Ledger__c = NULL)';
        }
        else {
            ledgerCondition = 'AND Ledger__c = :ledgerId';
        }

        String queryCondition =
            'Employee__c = :employeeId ' +
            'AND Time_Card_Period__r.Status__c = :timeCardPeriodStatus ' +
            ledgerCondition;

        SOQLBuilder theQuery = new SOQLBuilder(Time_Card__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Time_Card__c>) Database.query(theQuery.toSOQL());
    }

    private List<Time_Card_Period__c> queryTimeCardPeriods(String status, Set<Id> timeCardPeriods) {
        List<String> queryFields = new List<String>{
            'Id', 'Name'
        };
        String queryCondition = 'Status__c = :status AND Id NOT IN :timeCardPeriods ORDER BY Start_Date__c ASC';

        SOQLBuilder theQuery = new SOQLBuilder(Time_Card_Period__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Time_Card_Period__c>) Database.query(theQuery.toSOQL());
    }

    public List<SelectOption> getTimeCardPeriods() {
        Set<Id> timeCardPeriods = new Set<Id>();
        List<SelectOption> options = new List<SelectOption>();

        try {
            for (Time_Card__c tc : queryTimeCards(timeCard.Employee__c, 'Open', timeCard.Ledger__c)) {
                timeCardPeriods.add(tc.Time_Card_Period__c);
            }

            for (Time_Card_Period__c period : queryTimeCardPeriods('Open', timeCardPeriods)) {
                options.add(new SelectOption(period.Id, period.Name));
            }

            if (options.isEmpty()) {
                options.add(new SelectOption('', Label.SELECT_OPTION_NONE));
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }

        return options;
    }

    //This class saves and redirects the page back to the Time Card.
    public PageReference saveback() {
        if (timeCard.Employee__c == NULL) {
            isEmployeeError = true;
        }
        else {
            isEmployeeError = false;
        }

        if (timeCard.Time_Card_Period__c == NULL) {
            isPeriodError = true;
        }
        else {
            isPeriodError = false;
        }

        if (timeCard.Ledger__c == NULL) {
            isLedgerError = true;
        }
        else {
            isLedgerError = false;
        }

        if (isEmployeeError || isPeriodError || isLedgerError) {
            return NULL;
        }

        try {
            SFDCSecurityUtils.upsertCheckCRUDAndFLS(timeCard, new List<String>{
                'Employee__c',
                'Status__c'
            });
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            return NULL;
        }

        PageReference theEditPage = new ApexPages.StandardController(timeCard).edit();
        theEditPage.setRedirect(true);
        return theEditPage;
    }

}
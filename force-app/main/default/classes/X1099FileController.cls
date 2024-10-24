public with sharing class X1099FileController {

    private static final String CREATE_FILE_BATCH_CLASS = 'Create1099FileBatch';
    private static final String JOB_STARTED = Label.INF_JOB_STARTED;
    private static final String JOB_IN_PROGRESS_ERROR =
        Label.ERR_JOB_IN_PROGRESS;
    @TestVisible
    private static final String EMPTY_LEDGER = Label.ERR_EMPTY_LEDGER;
    private static final Set<String> APEX_JOB_IN_PROGRESS_STATUSES = GlobalVariables.APEX_JOB_STATUSES;

    private ApexPages.StandardSetController stdSetController;

    public String selectedYear {get; set;}
    public String selectedLedger {get; set;}
    public String selectedFormType {get; set;}
    public List<SelectOption> availableLedgers {get; set;}
    public List<SelectOption> availableYears {get; set;}
    public List<SelectOption> availableFormTypes {get; set;}
    public Boolean jobStarted {get; set;}

    public X1099FileController(ApexPages.StandardSetController setCon) {
        this.stdSetController = setCon;
        jobStarted = false;
        populateAvailableYears();
        populateAvailableLedgers();
        populateFormTypes();
    }

    public String getListViewId() {
        return stdSetController.getFilterId();
    }

    public String getSObjectApiName() {
        return Cash_Disbursement__c.SObjectType.getDescribe().getName();
    }

    public PageReference create1099File() {
        if (isJobInProgress()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, JOB_IN_PROGRESS_ERROR));
            return NULL;
        }

        if (String.isBlank(selectedLedger)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, EMPTY_LEDGER));
            return NULL;
        }

        try {
            //check CRUD&FLS for standard sobjects used in the batch instance =================
            // Account
            SFDCSecurityUtils.checkRead(Account.SObjectType, new List<String>{
                'Taxpayer_Identification_Number__c',
                'BillingStreet',
                'BillingCity',
                'BillingState',
                'BillingPostalCode',
                'Default_1099_Box__c'
            });
            // Contact
            SFDCSecurityUtils.checkRead(Contact.SObjectType, new List<String>{
                'Taxpayer_Identification_Number__c',
                'MailingStreet',
                'MailingCity',
                'MailingState',
                'MailingPostalCode',
                'Default_1099_Box__c'
            });
            //=================================================================================
            X1099File2Batch batchInstance = new X1099File2Batch(selectedYear, (Id) selectedLedger, (Id) selectedFormType);
            Id jobId = Database.executeBatch(batchInstance);
            jobStarted = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, JOB_STARTED));
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }

        return NULL;
    }

    private void populateAvailableYears() {
        availableYears = new List<SelectOption>();

        for (Integer i = 0; i <= 5; i++) {
            Integer year = System.today().addYears(-i).year();
            SelectOption option = new SelectOption(String.valueOf(year), String.valueOf(year));
            availableYears.add(option);
        }
    }

    private void populateFormTypes() {
        availableFormTypes = new List<SelectOption>();
        for (Form_Type__mdt formTypes : getFormTypes()) {
            SelectOption option = new SelectOption((String)formTypes.Id, (String)formTypes.Type__c);
            availableFormTypes.add(option);
        }
    }

    public PageReference getApplicableFormTypes(){
        populateFormTypes();
        return null;
    }

    public List<Form_Type__mdt> getFormTypes() {
        List<Form_Type__mdt> resultList = new List<Form_Type__mdt>();
        Integer intSelectedYear = selectedYear != NULL? Integer.valueOf(selectedYear) : null;
       
        map<string, Form_Type__mdt> formTypeMap = new map<string, Form_Type__mdt>();
        //dump the results sorted ascending into a map.  If the key (form type) already exists the value gets updated
        //essentially doing a max year on the type
        for(Form_Type__mdt formType : X1099InfoHelper.getFormTypesOrderByTypeYearASC(intSelectedYear)){
            formTypeMap.put(formType.Type__c, formType);
        }
        resultList = formTypeMap.values();
        return resultList;
    }

    private void populateAvailableLedgers() {
        availableLedgers = new List<SelectOption>();
        Id defaultLedgerId = LedgerHandler.getLedgerId();
        Ledger__c defaultLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(defaultLedgerId);
        //Default ledger will be first in list
        SelectOption option = new SelectOption(defaultLedger.Id, defaultLedger.Name);
        availableLedgers.add(option);
        //put other Transaction Ledgers in list
        for (Ledger__c eachLedger : LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers()) {
            if (eachLedger.Id != defaultLedgerId) {
                SelectOption opt = new SelectOption(eachLedger.Id, eachLedger.Name);
                availableLedgers.add(opt);
            }
        }
    }

    private static Boolean isJobInProgress() {
        //=============================================================
        // This is a system object. No need to check user access to it.
        //=============================================================
        List<AsyncApexJob> apexJobInAction = DomainUtils.getAsyncApexJobByApexClassNameAndStatus(
            new Set<String>{CREATE_FILE_BATCH_CLASS}, APEX_JOB_IN_PROGRESS_STATUSES
        );
        return !apexJobInAction.isEmpty();
    }
}
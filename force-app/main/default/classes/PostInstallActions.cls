global without sharing class PostInstallActions implements InstallHandler {

    @TestVisible private List<GL_Account__c> glAccounts;
    @TestVisible private List<GL_Account__c> glAccountsExpense;
    @TestVisible private List<Ledger__c> ledgers;
    @TestVisible private List<Billing_Format__c> billingFormats;
    @TestVisible private List<Accounting_Settings__c> settings;
    @TestVisible private List<Accounting_Period__c> acctPeriods;
    @TestVisible private List<Time_Card_Period__c> timeCardPeriods;
    @TestVisible private Ledger_Custom_Settings__c ledgerSettings;
    @TestVisible private List<Period_Task__c> accountingPeriodTasks;
    @TestVisible private static final String BILLING_PRODUCT_PDF_PAGE = 'BillingProductIrisPdfHLP';
    @TestVisible private static final String BILLING_SERVICE_PDF_PAGE = 'BillingServiceIrisPdfHLP';
    @TestVisible private static final String BILLING_EMAIL_TEMPLATE = 'Billing_Email_Template';
    @TestVisible private static final String OUTSTANDING_PDF_PAGE = 'BillingOutstandingStmtModernPDF';
    @TestVisible private static final String OUTSTANDING_EMAIL_TEMPLATE = 'Outstanding_Statement_Email_Template';
    @TestVisible private static final String ACTIVITY_PDF_PAGE = 'BillingActivityStmtModernPDF';
    @TestVisible private static final String ACTIVITY_EMAIL_TEMPLATE = 'Activity_Statement_Email_Template';
    @TestVisible private static final String CURRENCY_FORMAT = '$###,##0.00;($###,##0.00)';
    @TestVisible private static final String NUMERIC_FORMAT = '##,##0.00;(##,##0.00)';
    private static final String BILLING_FORMAT_IMAGE = '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';

    @TestVisible private static final String CASH_4015_UNAPPLIED_REVENUE = '4015-Unapplied Revenue';
    @TestVisible private static final String CASH_8000_UNAPPLIED_EXPENSE = '8000-Unapplied Expense';
    @TestVisible private static final Map<String, String> GL_ACCT_DEF_SPECS_BY_GL_ACCT_NAMES = new Map<String, String>{
            CASH_4015_UNAPPLIED_REVENUE => GLAccountDefaultsHandler.UNAPPLIED_REVENUE_GL_ACCOUNT,
            CASH_8000_UNAPPLIED_EXPENSE => GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT
    };

    public class PostInstallException extends Exception {}

    global void onInstall(InstallContext context) {

        if (!context.isUpgrade()) {
            dataSetup();
            // BDC method used for insert binding custom setting records based on binding metadata records 
            //for new install defualt Yodlee to inactive  
            insertBindingCustomSetting(false);
        }   

        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(2,20)) < 0) {
            updateBillingFormats();
        }

        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(2,21)) < 0) {
            createCustomerStatementFormats();
        }

        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,16)) < 0) {
            updatePrepaidExpenseGLAccount();
        }

        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,36)) < 0) {
            populateLedgerInfo();
        }

        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,46)) < 0) {
            setLegacyInventoryValuationMethod();
        }
        //IRVING
        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,51)) < 0) {
            setLineLevelPostAndAutoPostUpgradeSettings();
        }
        //KERMIT
        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,81)) < 0) {
            setAutomatedJobResultsRetentionPeriodSettings();
            setupAccountingPeriodRecurringTaskSampleData();
        }
        //MAGHOME
        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,100)) < 0) {
            setNewInMagHomeFieldsOnAcctSettings();
            updateBillingFormatsEmailDelivery();
        }
        //SUMMER 22
        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,121)) < 0) {
            createAndSetTaxSettings();
        }

        //SPRING 23 Pre 1
        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,133)) < 0) {
            insertBindingCustomSetting(true);
        }  

        //SPRING 23
        if (!context.isUpgrade() || context.previousVersion().compareTo(new Version(3,148)) < 0) {
            createGLAccountDefaultsRecords(!context.isUpgrade());
        }   

        // SUMMER 23 Pre 1
        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,155)) < 0) {
            setAutoPostSourceDocsFields();
            createGLAccountDefaultsRecords(!context.isUpgrade(), true);
        }

        // SUMMER 23 Pre 2
        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,156)) < 0) {
            Payment_Processor__c pp = createPaymentProcessor();
            if(pp != null){
                updatePaymentMethods(pp.Id);
            }
        } 

        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,157)) > 0) {
            sendLedDataAsynchronously();
        }

        //SUMMER 24 Pre 1
        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,235)) < 0) {
            createUnappliedCashGLAccounts();
            createConnectionNameForExistingAccessTokens();
            setCashDisbursementSourcePayable();
        }

        //Summer 24 Pre 2
        //adding this to activateLedgersAsychronously method to be run after ledgers are activated
        /*if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,236)) < 0) {
            createConnectionNameForExistingGLAM();
        }*/


        if (context.isUpgrade() && context.previousVersion().compareTo(new Version(3,235)) <= 0) {
            activateLedgersAsynchronously();
        }

        if (context.isUpgrade() && !Test.isRunningTest()) {
            presetLedgerAccountingMethod(null, LedgerActions.ACCOUNTING_METHOD_ACCRUAL);
        }

    }

    @Future
    public static void createUnappliedCashGLAccounts() {
        try {
            List<String> glAccountNames = new List<String>{
                    CASH_4015_UNAPPLIED_REVENUE,
                    CASH_8000_UNAPPLIED_EXPENSE
            };
            List<GL_Account__c> glAccounts = DomainUtils.getGlAccountsByName(glAccountNames);
            Map<String, GL_Account__c> glAccountsByNames = new Map<String, GL_Account__c>();
            for (GL_Account__c glAccount : glAccounts) {
                glAccountsByNames.put(glAccount.Name, glAccount);
            }

            Map<String, GL_Account__c> unappliedCashGLAccountsByNames = unappliedCashGLAccountsByNames();
            for (String glAccountName : glAccountNames) {
                if (glAccountsByNames.containsKey(glAccountName)) {
                    unappliedCashGLAccountsByNames.remove(glAccountName);
                }
            }

            if (!unappliedCashGLAccountsByNames.isEmpty()) {
                SFDCSecurityUtils.insertProxy(unappliedCashGLAccountsByNames.values());
            }

            Set<Id> ledgeIds = new Set<Id>();
            ledgeIds.addAll(new Map<Id, Ledger__c> (LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers()).keySet());
            ledgeIds.addAll(new Map<Id, Ledger__c> (LedgerHandler.getInstanceWithoutSharing().getBudgetLedgers()).keySet());

            Map<Id, Map<String, GL_Account_Default__c>> glAccountDefaultsMapByLedgerId = GLAccount.glAccountDefaultsMapByLedgerId(ledgeIds);
            glAccountsByNames.putAll(unappliedCashGLAccountsByNames);

            List<GLAccountDefault> glAccountDefaults = new List<GLAccountDefault>();
            for (Id ledgerId : ledgeIds) {
                for (String glAccountName : glAccountsByNames.keySet()) {
                    String glAcctDef = glAccountDefaultsMapByLedgerId.get(ledgerId)?.get(GL_ACCT_DEF_SPECS_BY_GL_ACCT_NAMES.get(glAccountName))?.GL_Account__c;
                    if (String.isBlank(glAcctDef)) {
                        GL_Account__c glAccount = glAccountsByNames.get(glAccountName);
                        String specification = GL_ACCT_DEF_SPECS_BY_GL_ACCT_NAMES.get(glAccountName);
                        GLAccountDefault def = new GLAccountDefault();
                        def.ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId);
                        def.glAccount = glAccount;
                        def.glAccountSpecification = new GL_Account_Specification__mdt(DeveloperName = specification);
                        def.glAccountDefault = new GL_Account_Default__c(
                                GL_Account__c = glAccount.Id,
                                GL_Account_Specification__c = specification,
                                Ledger__c = ledgerId
                        );
                        glAccountDefaults.add(def);
                    }
                }
            }
            if (!glAccountDefaults.isEmpty()) {
                GLAccountDefaultActions.isPreventUpdateOverride = true;
                GLAccount.saveDefaults(glAccountDefaults);
                GLAccountDefaultActions.isPreventUpdateOverride = false;
            }
        } catch (Exception e) {}

    }

    @Future
    public static void activateLedgersAsynchronously() {
        try {
            SOQLBuilder theQuery = new SOQLBuilder(Ledger__c.SObjectType);
            theQuery
                    .setEnforceFLS(false)
                    .selectFields(new List<String>{'Id'})
                    .setCondition(GlobalVariables.PACKAGE_QUALIFIER + 'Active__c = false');

            List<Ledger__c> ledgers = (List<Ledger__c>) Database.query(theQuery.toSOQL());
            for (Ledger__c ledger : ledgers) {
                ledger.put(GlobalVariables.PACKAGE_QUALIFIER + 'Active__c', true);
            }
            if (!ledgers.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Ledger__c.Active__c);
                SFDCSecurityUtils.updateProxy(ledgers);
                TriggerObserver.purgeUnlockedFields(Ledger__c.Active__c);
            }
            //call createConnectionNameForExistingGLAM method now that the ledgers are active
            createConnectionNameForExistingGLAM();
        } catch (Exception e) {}
    }

    public static void presetLedgerAccountingMethod(String fromAcctMethod, String toAcctMethod) {
        try {
            SOQLBuilder theQuery = new SOQLBuilder(Ledger__c.SObjectType);
            theQuery
                    .setEnforceFLS(false)
                    .selectFields(new List<String>{'Id'})
                    .setCondition(GlobalVariables.PACKAGE_QUALIFIER + 'Accounting_Method__c =: fromAcctMethod');

            List<Ledger__c> ledgers = (List<Ledger__c>) Database.query(theQuery.toSOQL());
            for (Ledger__c ledger : ledgers) {
                ledger.put(GlobalVariables.PACKAGE_QUALIFIER + 'Accounting_Method__c', toAcctMethod);
            }
            if (!ledgers.isEmpty() && ledgers.size() < 100) {
                TriggerObserver.getInstance().unlockField(Ledger__c.Accounting_Method__c);
                SFDCSecurityUtils.updateProxy(ledgers);
                TriggerObserver.purgeUnlockedFields(Ledger__c.Accounting_Method__c);
            }
        } catch (Exception e) {}
    }

    @future(Callout=true)
    private static void sendLedDataAsynchronously(){
        LEDService.sendData();
    }

    public void setAutoPostSourceDocsFields() {
        try {
            List<SObjectField> fields = new List<SObjectField>{
                Accounting_Settings__c.Auto_Post_Amortization_Entries__c,
                Accounting_Settings__c.Auto_Post_AP_Disbursements__c,
                Accounting_Settings__c.Auto_Post_Billing_Cash_Receipts__c,
                Accounting_Settings__c.Auto_Post_Cash_Receipts__c,
                Accounting_Settings__c.Auto_Post_Inventory_Movements__c
            };

            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
            Boolean legacyAutoPostSDs = true;
            try {
                legacyAutoPostSDs = (Boolean) acctSettings.get('Auto_Post_Source_Documents__c');
            }
            catch (System.SObjectException sObjEx) {
                //failed attempt to get value from deleted field (Auto_Post_Source_Documents__c is deleted from the package in Spring 24)
            }
            for (SObjectField field : fields) {
                acctSettings.put(field, legacyAutoPostSDs);
            }

            AccountingSettingsActions.isPreventUpdateOverride = true;
            AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = true;
            SFDCSecurityUtils.updateProxy(acctSettings);
            AccountingSettingsActions.isPreventUpdateOverride = false;
            AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
        } catch (Exception ex) {
            throw new PostInstallException(Label.ERR_POST_INSTALL_AUTO_POST_SETTINGS_UPDATE + ' ' + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    public static void createGLAccountDefaultsRecords(Boolean isFreshInstall) {
        createGLAccountDefaultsRecords(isFreshInstall, false);
    }

    public static void createGLAccountDefaultsRecords(Boolean isFreshInstall, Boolean isRunOnly4Consolidation) {
        Set<Id> ledgeIds = new Set<Id>(LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().keySet());
        if (isRunOnly4Consolidation) {
            ledgeIds.removeAll(new Map<Id, Ledger__c> (LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers()).keySet());
            ledgeIds.removeAll(new Map<Id, Ledger__c> (LedgerHandler.getInstanceWithoutSharing().getBudgetLedgers()).keySet());
        }
        createGLAccountDefaultsRecords(isFreshInstall, ledgeIds);
    }

    public static void createGLAccountDefaultsRecords(Boolean isFreshInstall, Set<Id> ledgeIds){
        try{
            if (!isFreshInstall || Test.isRunningTest()) {
                GLAccountDefaultsHandler.instance.setExistedGLAccountsFromSettings();
            }
            GLAccountDefaultActions.isPreventUpdateOverride = true;
            GLAccount.createGLAccountDefaultsByLedger(ledgeIds);
            GLAccountDefaultActions.isPreventUpdateOverride = false;
        }
        catch(Exception ex){
            throw new PostInstallException(Label.ERR_CANNOT_CREATE_GL_ACCOUNTS_DEFAULT + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    public void insertBindingCustomSetting(Boolean yodleeActive){
        try{
            
            // fetch all Bindings custom setting record if any in map where key will be name of record like yodlee,plaid etc.....
            Map<String, BDC_Binding__c> csBindings = BDC_Binding__c.getAll();
            //list to bulk insert missing bindings custom setting records based on metadata 
            List<BDC_Binding__c> bindingsToInsert = new List<BDC_Binding__c>();

                // if to make sure that custom setting records should only created for Yodlee and Plaid if there is not already a custom setting for them
                if(!csBindings ?.containsKey('Yodlee')){
                    BDC_Binding__c yodleeBinding = new BDC_Binding__c();
                    yodleeBinding.Name = 'Yodlee';
                    yodleeBinding.Type__c = 'AbstractBDCRouter'; 
                    yodleeBinding.To__c = 'YodleeBDCRouter';
                    yodleeBinding.Is_Active__c = yodleeActive;
                    bindingsToInsert.add(yodleeBinding);
                } 
                
                if(!csBindings ?.containsKey('Plaid')){
                    BDC_Binding__c plaidBinding = new BDC_Binding__c();
                    plaidBinding.Name = 'Plaid';
                    plaidBinding.Type__c = 'AbstractBDCRouter'; 
                    plaidBinding.To__c = 'PlaidBDCRouter';
                    plaidBinding.Is_Active__c = false;
                    bindingsToInsert.add(plaidBinding);
                }

            // finally insert all missing records of custom setting in DB.
            SFDCSecurityUtils.insertProxy(bindingsToInsert);
        }
        catch(Exception ex){
            throw new PostInstallException(Label.ERR_CANNOT_INSERT_BINDING_CUSTOM_SETTING + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    private Boolean isProfessionalEdition() {
        return FinancialSuiteUtils.getSalesforceEdition() == 'Professional Edition';
    }

    private Boolean isAccountingSettingsAndInstanceValid(Accounting_Settings__c acctSettings) {
        return !(FinancialSuiteUtils.isOrganizationInstanceSandbox && acctSettings.Id == NULL);
    }

    /*
    *   1. Populate Default Amortizing Accounts
    *   2. Populate Credit Memo Default value as "Amount"
    * */
    private void setNewInMagHomeFieldsOnAcctSettings() {
        try {
            List<String> queryFields = new List<String>{
                'Id', 'Name'
            };
            String queryCondition = 'Name = \'2500-Deferred Revenue\'';

            SOQLBuilder theQuery = new SOQLBuilder(Gl_Account__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(1);

            List<GL_Account__c> glAccount2500 = (List<GL_Account__c>) Database.query(theQuery.toSOQL());

            GL_Account__c glAccount1450 = new GL_Account__c(
                Name = '1450-Deferred Expenses',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'
            );
            SFDCSecurityUtils.insertProxy(glAccount1450);

            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();

            if (isAccountingSettingsAndInstanceValid(acctSettings)) {
                AccountingSettingsActions.isPreventUpdateOverride = true;
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = true;
                acctSettings.Default_Credit_GL_Account_Expense__c = glAccount1450.Id;
                acctSettings.Default_Debit_GL_Account_Revenue__c = !glAccount2500.isEmpty() ? glAccount2500[0].Id : null;

                acctSettings.Credit_Memo_Default__c = 'Amount';

                SFDCSecurityUtils.updateProxy(acctSettings);
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                AccountingSettingsActions.isPreventUpdateOverride = false;
            }
        }
        catch (Exception ex) {
            throw new PostInstallException(Label.ERR_CANNOT_UPDATE_ACCOUNTING_SETTING + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }
    /*
    *   1. create a payment processor 
    *   2. Create payment processor customer for all the accounts where stripe id is populated
    *   3. Update the accounting setting with payment processor Id
    * */
    private Payment_Processor__c createPaymentProcessor() {
        try {
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
            if (String.isNotBlank(acctSettings?.Stripe_Connected_Account_Id__c) && !acctSettings.Stripe_Connected_Account_Id__c.trim().equalsIgnoreCase('null')){
                Payment_Processor__c paymentProcessor = new Payment_Processor__c(
                    Connected_Account_Token__c = acctSettings.Stripe_Connected_Account_Id__c,
                    Active__c = true,
                    Test_Mode__c = false,
                    Type__c = PaymentProcessorActions.STRIPE_TYPE, 
                    Name = PaymentProcessorActions.STRIPE_TYPE
                );

                SFDCSecurityUtils.insertProxy(paymentProcessor);

                //repourpose Stripe_Connected_Account_Id__c to hold global default payment processor
                //AccountingSettingsActions.isPreventUpdateOverride = true;
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = true;
                updateAccountingSetting(acctSettings,paymentProcessor);
                //AccountingSettingsActions.isPreventUpdateOverride = false;
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;

                List<Account> accts = DomainUtils.getAccountWhereStripeCustomeIdIsPresent();
                //if no accounts then return payment processor
                if(accts.size() == 0){
                    return paymentProcessor;
                }

                //create payment processor customers for all the accounts and attach them with payment processor
                createPaymentProcessorCustomer(paymentProcessor,accts);

                return paymentProcessor;
            }
            return null;
        } catch (Exception ex) {
            throw new PostInstallException(Label.ERR_POST_INSTALL_PMT_PROCESSOR_ERROR + ' ' + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }
    /**
     * create payment processor customer for all the accounts
     */
    private void createPaymentProcessorCustomer(Payment_Processor__c paymentProcessor,List<Account> accts){
        List<Payment_Processor_Customer__c> ppcs = new List<Payment_Processor_Customer__c>();
        for(Account acct : accts){
            ppcs.add(new Payment_Processor_Customer__c(
                Account__c = acct.Id, 
                External_Id__c = acct.Stripe_Customer_Id__c,
                Processor__c = paymentProcessor.Id
            ));
        } 
        SFDCSecurityUtils.insertProxy(ppcs);
    }
    /**
     * update payment methods with new payment processor
     */
    @future
    private static void updatePaymentMethods(String ppId){
        try{
            List<Payment_Method__c> payments = DomainUtils.getAllPaymentMethods();
            for(Payment_Method__c pm : payments){
                pm.Payment_Processor__c = ppId;
            }
            SFDCSecurityUtils.updateProxy(payments);
        }catch(Exception e){

        }
    }
    /**
     * update accounting setting stripe Id with payment processor Id
     */
    private void updateAccountingSetting(Accounting_Settings__c acctSettings, Payment_Processor__c pp){
        acctSettings.Stripe_Connected_Account_Id__c = pp.Id;
        SFDCSecurityUtils.updateProxy(acctSettings);
    }
    private void createAndSetTaxSettings() {
        try {
            List<Ledger__c> transLedgers = DomainUtils.getLedgerByType(new Set<String> {'Transactional'});
            if (!transLedgers.isEmpty()) {
                Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
                Tax_Settings__c taxSetting;

                for (Ledger__c ledger : transLedgers) {
                    if (ledger.Tax_Settings__c == null) {
                        taxSetting = taxSetting == null ? getTaxSettings() : taxSetting;
                        ledger.Tax_Settings__c = taxSetting.Id;
                        if (acctSettings.Enable_Avalara_Tax_Calculation__c) {
                            ledger.Sales_Tax_Company_Code__c = acctSettings.Company_Code__c;
                        }
                    }
                }

                SFDCSecurityUtils.updateProxy(transLedgers);
            }
        }
        catch (Exception ex) {
            throw new PostInstallException(Label.ERR_CANNOT_UPDATE_LEDGER_RECORDS + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    private Tax_Settings__c getTaxSettings() {
        Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
        Tax_Settings__c taxSetting = new Tax_Settings__c();
        taxSetting.Name = acctSettings.Enable_Avalara_Tax_Calculation__c ? TaxSettingsActions.AVA_TAX_METHOD : TaxSettingsActions.NATIVE_TAX_METHOD;
        taxSetting.Tax_Settings_Method__c = acctSettings.Enable_Avalara_Tax_Calculation__c ? TaxSettingsActions.AVA_TAX_METHOD : TaxSettingsActions.NATIVE_TAX_METHOD;
        taxSetting.Sales_Tax_GL_Account__c = acctSettings.Avalara_Sales_Tax_GL_Account__c;
        taxSetting.Sales_Tax_Product__c = acctSettings.Avalara_Tax_Product__c;
        taxSetting.Sales_Tax_Calculation_Mode__c = getTaxCalcModeFromAcctSettings(acctSettings);

        if (isAddressPopulated(acctSettings)) {
            taxSetting.Origin_Address__c = getOriginAddress().Id;
        }
        if (acctSettings.Enable_Avalara_Tax_Calculation__c) {
            taxSetting.AvaTax_License__c = getAvalaraLicense().Id;
        }
        TaxSettingsActions.isPreventUpdateOverride = true;
        SFDCSecurityUtils.insertProxy(taxSetting);
        TaxSettingsActions.isPreventUpdateOverride = false;
        return taxSetting;
    }

    private String getTaxCalcModeFromAcctSettings(Accounting_Settings__c settings) {
        String result;
        if (settings.Tax_Calculation_Mode__c == 'POS') {
            result = 'Point of Sale';
        }
        else if (settings.Tax_Calculation_Mode__c == 'POD') {
            result = 'Point of Destination';
        }
        else if (settings.Tax_Calculation_Mode__c == 'Shipment') {
            result = 'Shipment';
        }
        return result;
    }

    private Boolean isAddressPopulated(Accounting_Settings__c acctSettings) {
        return acctSettings.City__c != null
            && acctSettings.Country_Code__c != null
            && acctSettings.Postal_Code__c != null
            && acctSettings.Region__c != null
            && acctSettings.Street__c != null;
    }

    private Address__c getOriginAddress() {
        Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
        Address__c address = new Address__c();
        address.City__c = acctSettings.City__c;
        address.Country_Code__c = acctSettings.Country_Code__c;
        address.Postal_Code__c = acctSettings.Postal_Code__c;
        address.State_Province__c = acctSettings.Region__c;
        address.Street__c = acctSettings.Street__c;

        SFDCSecurityUtils.insertProxy(address);
        return address;
    }

    private AvaTax_License__c getAvalaraLicense() {
        Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
        AvaTax_License__c newLicense = new AvaTax_License__c();
        newLicense.Active_AvaTax_Endpoint__c = acctSettings.Avalara_Production_Endpoint__c ? 'Production' : 'Sandbox';
        newLicense.AvaTax_Account_ID__c = acctSettings.Avalara_Account_Id__c;
        newLicense.AvaTax_License_Key__c = acctSettings.Avalara_License_Key__c;

        SFDCSecurityUtils.insertProxy(newLicense);
        return newLicense;
    }

    private void updateBillingFormatsEmailDelivery(){
        try {
            List<Billing_Format__c> billingFormats = new List<Billing_Format__c>();
            List<String> queryFields = new List<String>{
                'Id', 'Automated_Email_Delivery2__c', 'Automated_Email_Delivery__c'
            };

            SOQLBuilder theQuery = new SOQLBuilder(Billing_Format__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setLimit(50000);

            billingFormats = Database.query(theQuery.toSOQL());

            for (Billing_Format__c billFormat : billingFormats) {
               switch on billFormat.Automated_Email_Delivery__c {
                    when 'Balance Due' {		
                        billFormat.Automated_Email_Delivery2__c = 'Balance Due Only';
                    }
                    when 'Zero Balance' {		
                        billFormat.Automated_Email_Delivery2__c = 'Zero Balance Only';
                    }	
                    when 'No Delivery' {		
                        billFormat.Automated_Email_Delivery2__c = 'No Delivery';
                    }		
                }
            }
            
            SFDCSecurityUtils.updateProxy(billingFormats);
        }
        catch (Exception ex) {
            
        }

    }

    private void setLegacyInventoryValuationMethod() {
        try {
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
            if (isAccountingSettingsAndInstanceValid(acctSettings)) {
                acctSettings.Inventory_Valuation_Method__c = 'Standard Cost';
                AccountingSettingsActions.isPreventUpdateOverride = true;
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = true;
                SFDCSecurityUtils.updateProxy(acctSettings);
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                AccountingSettingsActions.isPreventUpdateOverride = false;
            }
        }
        catch (Exception ex) {
            throw new PostInstallException(Label.ERR_CANNOT_UPDATE_ACCOUNTING_SETTING + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    private void setLineLevelPostAndAutoPostUpgradeSettings() {
        try {
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
            if (isAccountingSettingsAndInstanceValid(acctSettings)) {
                AccountingSettingsActions.isPreventUpdateOverride = true;
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = true;
                acctSettings.Post_Settings__c = 'Line-Level Post';
                SFDCSecurityUtils.updateProxy(acctSettings);
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                AccountingSettingsActions.isPreventUpdateOverride = false;
            }
        }
        catch (Exception ex) {
            throw new PostInstallException(Label.ERR_CANNOT_UPDATE_ACCOUNTING_SETTING + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    private void setAutomatedJobResultsRetentionPeriodSettings() {
        try {
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
            if (isAccountingSettingsAndInstanceValid(acctSettings)) {
                AccountingSettingsActions.isPreventUpdateOverride = true;
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = true;
                acctSettings.Enable_Retention_Period__c = false;
                acctSettings.Automated_Job_Results_Retention_Days__c = 30;
                SFDCSecurityUtils.updateProxy(acctSettings);
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                AccountingSettingsActions.isPreventUpdateOverride = false;
            }
        }
        catch (Exception ex) {
            throw new PostInstallException(Label.ERR_CANNOT_UPDATE_ACCOUNTING_SETTING + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    private void populateLedgerInfo() {
        try {
            //get Accounting Settings record
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
            //prevent update settings when environment is sandbox and accounting setting row does not exist
            if (isAccountingSettingsAndInstanceValid(acctSettings)) {
                //fill Ledger custom setting
                ledgerSettings = Ledger_Custom_Settings__c.getOrgDefaults();
                ledgerSettings.Ledger_Id__c = acctSettings.Default_Ledger__c;
                SFDCSecurityUtils.upsertProxy(ledgerSettings);
                //update some Ledger related fields on Accounting Settings record
                acctSettings.Legacy_Default_Ledger__c = acctSettings.Default_Ledger__c;
                acctSettings.Ledger_Limit__c = 1;
                AccountingSettingsActions.isPreventUpdateOverride = true;
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = true;
                SFDCSecurityUtils.updateProxy(acctSettings);
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                AccountingSettingsActions.isPreventUpdateOverride = false;
            }
        }
        catch (Exception ex) {
            throw new PostInstallException(Label.ERR_CANNOT_UPDATE_ACCOUNTING_SETTING_OR_LEDGER_RECORDS + ex.getMessage() + '\n' + ex.getStackTraceString());
        }

        try {
            //All existed Transactional Ledgers in an organization must be updated;
            //Default PDF formats and Default Bank Account will be carried over from Accounting Settings record.
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
            //prevent update settings when environment is sandbox and accounting setting row does not exist
            if (isAccountingSettingsAndInstanceValid(acctSettings)) {
                List<Ledger__c> transLedgers = DomainUtils.getLedgerByType(new Set<String> {'Transactional'});
                if (!transLedgers.isEmpty()) {
                    for (Ledger__c ledger : transLedgers) {
                        //move PDF formats from Accounting Settings
                        ledger.Billing_Activity_Statement_Format__c = acctSettings.Billing_Activity_Statement_Format__c;
                        ledger.Billing_Outstanding_Statement_Format__c = acctSettings.Billing_Outstanding_Statement_Format__c;
                        ledger.Default_Billing_Format__c = acctSettings.Default_Billing_Format__c;
                        ledger.Default_Purchase_Order_Format__c = acctSettings.Default_Purchase_Order_Format__c;
                        ledger.Default_Packing_Slip_Format__c = acctSettings.Default_Packing_Slip_Format__c;
                        //move Bank Account from Accounting Settings
                        ledger.Default_Bank_Account__c = acctSettings.Default_Bank_Account__c;
                    }

                    TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{
                            Ledger__c.Billing_Activity_Statement_Format__c,
                            Ledger__c.Billing_Outstanding_Statement_Format__c,
                            Ledger__c.Default_Billing_Format__c,
                            Ledger__c.Default_Purchase_Order_Format__c,
                            Ledger__c.Default_Packing_Slip_Format__c,
                            Ledger__c.Default_Bank_Account__c
                    });
                    SFDCSecurityUtils.updateProxy(transLedgers);
                    TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{
                            Ledger__c.Billing_Activity_Statement_Format__c,
                            Ledger__c.Billing_Outstanding_Statement_Format__c,
                            Ledger__c.Default_Billing_Format__c,
                            Ledger__c.Default_Purchase_Order_Format__c,
                            Ledger__c.Default_Packing_Slip_Format__c,
                            Ledger__c.Default_Bank_Account__c
                    });
                }

                List<GL_Account_Mapping__c> updateGLMappings = new List<GL_Account_Mapping__c>();
                for (GL_Account_Mapping__c glm : DomainUtils.getGLAccountMappings(false)) {
                    if (glm.Ledger__c == NULL) {
                        glm.Ledger__c = acctSettings.Default_Ledger__c;
                        updateGLMappings.add(glm);
                    }
                }

                SFDCSecurityUtils.updateProxy(updateGLMappings);
            }
        }
        catch (Exception ex) {
            throw new PostInstallException(Label.ERR_CANNOT_UPDATE_LEDGER_OR_GL_ACCOUNT_MAPPING_RECORDS + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    private void updateBillingFormats() {
        try {
            List<Billing_Format__c> billingFormats = new List<Billing_Format__c>();
            List<String> queryFields = new List<String>{
                'Id', 'Visualforce_PDF_Page__c', 'Default_Email_Template__c'
            };

            SOQLBuilder theQuery = new SOQLBuilder(Billing_Format__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setLimit(50000);

            for (Billing_Format__c billFormat : (List<Billing_Format__c>) Database.query(theQuery.toSOQL())) {
                billFormat.Visualforce_PDF_Page__c = BILLING_PRODUCT_PDF_PAGE;
                billFormat.Default_Email_Template__c = BILLING_EMAIL_TEMPLATE;
                billFormat.Type__c = 'Billing';
                billFormat.Currency_Format__c = CURRENCY_FORMAT;
                billFormat.Numeric_Format__c = NUMERIC_FORMAT;
                billingFormats.add(billFormat);
            }
            
            SFDCSecurityUtils.updateProxy(billingFormats);
        }
        catch (Exception ex) {
            
        }
    }

    private void updatePrepaidExpenseGLAccount() {
        try {
            List<String> qur = new List<String>();
            List<Billing_Format__c> billingFormats = new List<Billing_Format__c>();

            List<String> queryFields = new List<String>{
                'Id', 'Name'
            };
            String queryCondition = 'Name = \'1400-Prepaid Expenses\'';

            SOQLBuilder theQuery = new SOQLBuilder(Gl_Account__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(1);

            GL_Account__c glAccount = (GL_Account__c) Database.query(theQuery.toSOQL());
            if (AccountingSettingsHandler.getAccountingSettings().Prepaid_Expense_GL_Account__c == NULL) {
                AccountingSettingsHandler.getAccountingSettings().Prepaid_Expense_GL_Account__c = glAccount.Id;
                SFDCSecurityUtils.updateProxy(AccountingSettingsHandler.getAccountingSettings());
            }
        }
        catch (Exception ex) {
            
        }
    }

    private static Map<String, GL_Account__c> unappliedCashGLAccountsByNames() {
        return new Map<String, GL_Account__c>{
                // 28
                CASH_4015_UNAPPLIED_REVENUE => new GL_Account__c(
                        Name = CASH_4015_UNAPPLIED_REVENUE,
                        Active__c = true,
                        Bank__c = false,
                        Type__c = 'Revenue'
                ),
                // 29
                CASH_8000_UNAPPLIED_EXPENSE => new GL_Account__c(
                        Name = CASH_8000_UNAPPLIED_EXPENSE,
                        Active__c = true,
                        Bank__c = false,
                        Type__c = 'Expense',
                        Sub_Type_1__c = 'General & Administrative'
                )
        };
    }

    private void createCustomerStatementFormats() {
        try {
            List<Billing_Format__c> billingFormats = new List<Billing_Format__c>();
            Billing_Format__c outstandingFormat = new Billing_Format__c();
            outstandingFormat.Name = 'Default Billing Outstanding Statement';
            outstandingFormat.Visualforce_PDF_Page__c = OUTSTANDING_PDF_PAGE;
            outstandingFormat.Default_Email_Template__c = OUTSTANDING_EMAIL_TEMPLATE;
            outstandingFormat.Type__c = 'Outstanding Statement';
            outstandingFormat.Image__c = '<img alt="Accounting Seed Logo" src="data:image/jpeg;base64,' + BILLING_FORMAT_IMAGE + '"></img>';
            outstandingFormat.Currency_Format__c = CURRENCY_FORMAT;
            outstandingFormat.Numeric_Format__c = NUMERIC_FORMAT;
            billingFormats.add(outstandingFormat);
            
            Billing_Format__c activityFormat = new Billing_Format__c();
            activityFormat.Name = 'Default Billing Activity Statement';
            activityFormat.Visualforce_PDF_Page__c = ACTIVITY_PDF_PAGE;
            activityFormat.Default_Email_Template__c = ACTIVITY_EMAIL_TEMPLATE;
            activityFormat.Type__c = 'Activity Statement';
            activityFormat.Image__c = '<img alt="Accounting Seed Logo" src="data:image/jpeg;base64,' + BILLING_FORMAT_IMAGE + '"></img>';
            activityFormat.Currency_Format__c = CURRENCY_FORMAT;
            activityFormat.Numeric_Format__c = NUMERIC_FORMAT;
            billingFormats.add(activityFormat);
            
            SFDCSecurityUtils.insertProxy(billingFormats);
            
            List<Accounting_Settings__c> settings = new List<Accounting_Settings__c>();

            SOQLBuilder theQuery = new SOQLBuilder(Accounting_Settings__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .setLimit(1000);

            for (Accounting_Settings__c setting : (List<Accounting_Settings__c>) Database.query(theQuery.toSOQL())) {
                setting.Billing_Outstanding_Statement_Format__c = billingFormats[0].Id;
                setting.Billing_Activity_Statement_Format__c = billingFormats[1].Id;
                settings.add(setting);
            }
            
            SFDCSecurityUtils.updateProxy(settings);
        }
        catch (Exception ex) {
            
        }
    }

    /*   
    * Summer24pre1 added a BDC feature to allow for multiple connections. 
    * The names of these connections were added to the access token custom setting.
    * This function sets those names on release so they are not null.
    */   
    @TestVisible
    private static void createConnectionNameForExistingAccessTokens() {
        List<BDC_Access_Tokens__c> allExistingAccessTokens = BDC_Access_Tokens__c.getAll().values();
        List<BDC_Access_Tokens__c> nullNameTokens = new List<BDC_Access_Tokens__c>();
        Map<String, Integer> instIdToNumberOfNamesToCreate = new Map<String, Integer>();

        //filter out any tokens with null identity names to get the count of the number of names to be created for existing tokens
        for (BDC_Access_Tokens__c aToken : allExistingAccessTokens) {
            if (aToken.Identity_Name__c == null) {
                String finInstId = aToken.Financial_Institution_Id__c;
                if (instIdToNumberOfNamesToCreate.get(finInstId) == null) {
                    instIdToNumberOfNamesToCreate.put(finInstId, 1);
                } else {
                    Integer previousNum = instIdToNumberOfNamesToCreate.get(finInstId);
                    instIdToNumberOfNamesToCreate.put(finInstId, previousNum + 1);
                }
                nullNameTokens.add(aToken);
            }    
        }    

        Integer tokenCounter = 0; 
        Map<String, List<String>> newNames = PlaidBDCIdentityComparator.createNewConnectionNames(instIdToNumberOfNamesToCreate);

        //a counter to keep track of which generated names have been used
        Map<String, Integer> institutionCounters = new Map<String, Integer>();
        for (String instId : newNames.keySet()) {
            institutionCounters.put(instId, 0);
        }
        for (BDC_Access_Tokens__c aToken : nullNameTokens) {
            Integer instCount = institutionCounters.get(aToken.Financial_Institution_Id__c);
            aToken.Identity_Name__c = newNames.get(aToken.Financial_Institution_Id__c)[instCount];
            institutionCounters.put(aToken.Financial_Institution_Id__c, instCount + 1);
        }    
        SFDCSecurityUtils.updateProxy(nullNameTokens);
    }

    /*
    * When the connection name field was added to the GLAM, previously existing GLAMS would had nulls in the field. 
    * This populats the connection names on those existing GLAMs
    */
    @TestVisible
    private static void createConnectionNameForExistingGLAM() {
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
        //find all glams with null connection name
        List<GL_Account_Mapping__c> glamsWithNoName = [SELECT Id, Connection_Name__c, Financial_Institution_Id__c FROM GL_Account_Mapping__c 
            WHERE Source__c = 'Plaid' AND Financial_Institution_Id__c != null AND Inactive__c = false AND Connection_Name__c = null];

        //the access tokens contain the name and identity id.
        List<BDC_Access_Tokens__c> accTokens = BDC_Access_Tokens__c.getAll().values();
        Map<String, BDC_Access_Tokens__c> idenIdToToken = new Map<String, BDC_Access_Tokens__c>();
        for (BDC_Access_Tokens__c aToken : accTokens) {
            idenIdToToken.put(aToken.Financial_Institution_Identity_Id__c, aToken); 
        }

        //update the connection name GLAM by matching it to the access token via the identity id
        for (GL_Account_Mapping__c glamNoName : glamsWithNoName) {
            glamNoName.Connection_Name__c = idenIdToToken.get(glamNoName.Financial_Institution_Id__c).Identity_Name__c;
        }
        SFDCSecurityUtils.updateProxy(glamsWithNoName);
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;

    }



    private void setCashDisbursementSourcePayable(){
        try {
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
            if(acctSettings.Cash_Disbursement_Source__c == NULL){
                acctSettings.Cash_Disbursement_Source__c = 'Payable';
                AccountingSettingsActions.isPreventUpdateOverride = true;
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = true;
                SFDCSecurityUtils.updateProxy(acctSettings);
                AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
                AccountingSettingsActions.isPreventUpdateOverride = false;                
            }
        }
        catch (Exception ex) {
            throw new PostInstallException(Label.ERR_CANNOT_UPDATE_ACCOUNTING_SETTING_OR_LEDGER_RECORDS + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
        
    }

    public void setupAccountingPeriodRecurringTaskSampleData() {
        //weekly, monthy, quarterly
        Date createDate = System.today().toStartOfMonth().addMonths(1);
        Date dueDate10 = createDate.addDays(9);
        Date dueDate15 = createDate.addDays(14);
        Date dueDateLastOfMonth = createDate.addMonths(1).addDays(-1);
        //annual
        Date createDateJan = date.newinstance(System.Date.today().addYears(1).year(), 1, 1);
        Date dueDateJan10 = date.newinstance(System.Date.today().addYears(1).year(), 1, 10);
        Date dueDateJan31 = date.newinstance(System.Date.today().addYears(1).year(), 1, 31);

        accountingPeriodTasks = new list<Period_Task__c>();
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'CLOSE: Verify all source records in the accounting period are posted.',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Verify all source records are posted prior to month-end close. Review unposted [source object] reports in Accounting Reports folder.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 1,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'CLOSE: Record month-end accruals',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'For accrual-based accounting, record transactions in the period in which they occur, regardless of the timing of payments.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 2,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'CLOSE: Record reversing-entries',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Record reversing entries in a subsequent accounting period to remove adjusting accrual entries that were made in the prior accounting period.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 3,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'CLOSE: Reconcile balance sheet accounts to sub-ledgers',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Reconcile GL balances of balance sheet accounts to any sub-ledgers (i.e. Inventory, Fixed Asset, Prepaid, etc.)',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 4,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'CLOSE: Close system Accounting Period',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Close the period to generate financial cubes and aging history records to generate financial statements and A/R & A/P Historical Agings.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 5,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'PAYROLL: Process payroll',
                Accounting_Period_Offset__c = '0',
                Comments__c = 'Process payroll from your payroll processor.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate15,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Weeks',
                Never__c = true,
                Priority__c = 'High',
                Frequency_Num__c = 2,
                Sort_Order__c = 6,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'CASH: Record all cash receipts',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Verify all received cash receipts are posted.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 7,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'CASH: Review outstanding check list for checks aged 60+ days',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Review outstanding checks not cashed for reissuance or void.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 8,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'CASH: Reconcile Bank Accounts',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Perform reconciliations for all bank and credit card accounts.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 9,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'AR/SALES: Review Customer Accounts Receivable past due',
                Accounting_Period_Offset__c = '0',
                Comments__c = 'Perform Days Sales Outstanding analysis and review of all at-risk receivables.',
                Create_Date__c = createDate,
                Due_Date__c = dueDateLastOfMonth,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Weeks',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 2,
                Sort_Order__c = 10,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'AR/SALES: Reconcile A/R Aging-Historical to the Trial Balance',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Reconcile the AR Aging sub-ledger to the Balance Sheet or Trial Balance.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 11,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'AR/SALES: Recognize revenue',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Review all outstanding contracts and perform revenue recognition/deferred revenue analyses.  Record earned revenue.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 12,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'AP/EXPENSE: Process Vendor Accounts Payable',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Record all received vendor invoices and evaluate for check run.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 13,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'AP/EXPENSE: Reconcile A/P Aging-Historical to the Trial Balance',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Reconcile the AP Aging sub-ledger to the Balance Sheet or Trial Balance.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 14,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'REPORTING: Generate Financial Statements',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Generate finalized P&L, Balance Sheet, Trial Balance, Cash Flow and ancillary statements or schedules',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 15,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'REPORTING: Perform variance and gross margin analysis on profit & loss accounts',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Analyses such as 12 month rolling trend analysis, current vs prior month, current year vs prior year, etc.',
                Create_Date__c = createDate,
                Due_Date__c = dueDate10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 16,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'TAX: Review sales tax and make quarterly payments',
                Accounting_Period_Offset__c = '-1',
                Comments__c = 'Pay estimated quarterly tax.',
                Create_Date__c = createDateJan,
                Due_Date__c = dueDateJan10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Months',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 3,
                Sort_Order__c = 17,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'TAX: File Forms 1099 and W-2',
                Accounting_Period_Offset__c = '0',
                Comments__c = 'File Forms 1099 for non-employee compensation and W-2 for employees',
                Create_Date__c = createDateJan,
                Due_Date__c = dueDateJan31,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Years',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 18,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'TAX: Update mileage reimbursement rate',
                Accounting_Period_Offset__c = '0',
                Comments__c = 'Update the Mileage GL account annually for new IRS mileage reimbursement rates',
                Create_Date__c = createDateJan,
                Due_Date__c = dueDateJan10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Years',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 19,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'ADMIN: Create new Accounting Periods for next 12 months',
                Accounting_Period_Offset__c = '0',
                Comments__c = 'Recommended best practice to maintain a minimum of 12 future accounting periods in the system.',
                Create_Date__c = createDateJan,
                Due_Date__c = dueDateJan10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Years',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 20,
                Status__c = 'Not Started'
            )
        );
        accountingPeriodTasks.add(
            new Period_Task__c(
                Name = 'ADMIN: Verify Form 1099 Box elections for 1099 vendors haven\'t changed',
                Accounting_Period_Offset__c = '0',
                Comments__c = 'If IRS changes Form 1099-MISC or Form 1099-NEC, then all affected 1099 vendors will have to be remapped to the correct Form Box mappings annually.',
                Create_Date__c = createDateJan,
                Due_Date__c = dueDateJan10,
                Ends_On__c = 'Never',
                Exclude_from_Automation__c = false,
                Frequency_Type__c = 'Years',
                Never__c = true,
                Priority__c = 'Normal',
                Frequency_Num__c = 1,
                Sort_Order__c = 21,
                Status__c = 'Not Started'
            )
        );

        try {
            SFDCSecurityUtils.insertProxy(accountingPeriodTasks);
        }
        catch (Exception ex) {
            throw new PostInstallException(Label.ERR_CANNOT_CREATE_ACCOUNTING_PERIOD_RECURRING_TASK_RECORDS + ex.getMessage() + '\n' + ex.getStackTraceString());
        }
    }

    public void dataSetup() {
        glAccounts = new List<GL_Account__c>();
        // 0
        glAccounts.add(
            new GL_Account__c(
                Name = '1000-Cash',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Bank__c = true,
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Cash'
            )
        );
        // 1
        glAccounts.add(
            new GL_Account__c(
                Name = '1200-Accounts Receivable',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'                
            )
        );
        // 2
        glAccounts.add(
            new GL_Account__c(
                Name = '1205-Unapplied A/R',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'
            )
        );
        // 3
        glAccounts.add(
            new GL_Account__c(
                Name = '1600-Work In Process',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'        
            )
        );
        // 4
        glAccounts.add(
            new GL_Account__c(
                Name = '2000-Accounts Payable',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Liabilities',
                Sub_Type_2__c = 'Current Liabilities'       
            )
        );
        // 5
        glAccounts.add(
            new GL_Account__c(
                Name = '2010-Vouchers Payable',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Liabilities',
                Sub_Type_2__c = 'Current Liabilities'       
            )
        );
        // 6
        glAccounts.add(
            new GL_Account__c(
                Name = '2020-Accrued Expenses',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Liabilities',
                Sub_Type_2__c = 'Current Liabilities'       
            )
        );
        // 7 
        glAccounts.add(
            new GL_Account__c(
                Name = '3000-Owners Equity',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Owners Equity',
                Sub_Type_2__c = 'Equity'        
            )
        );
        // 8
        glAccounts.add(
            new GL_Account__c(
                Name = '3050-Retained Earnings',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Owners Equity',
                Sub_Type_2__c = 'Equity'    
            )
        );
        // 9
        glAccounts.add(
            new GL_Account__c(
                Name = '3060-Current Year Earnings',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Owners Equity',
                Sub_Type_2__c = 'Equity'    
            )
        );
        // 10
        glAccounts.add(
            new GL_Account__c(
                Name = '4000-Product Revenue',
                Active__c = true,
                Type__c = 'Revenue',
                Sub_Type_1__c = 'Product Revenue',
                Sub_Type_2__c = 'Product Family 1'  
            )
        );
        // 11
        glAccounts.add(
            new GL_Account__c(
                Name = '4010-Services Revenue',
                Active__c = true,
                Type__c = 'Revenue',
                Sub_Type_1__c = 'Service Revenue',
                Sub_Type_2__c = 'Service Family 1'  
            )
        );
        // 12
        glAccounts.add(
            new GL_Account__c(
                Name = '5000-Cost of Goods Sold',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Cost of Goods Sold',
                Sub_Type_2__c = 'Materials'
            )
        );
        // 13
        glAccounts.add(
            new GL_Account__c(
                Name = '5040-Vendor Payment Discounts',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Cost of Goods Sold',
                Sub_Type_2__c = 'Materials'
            )
        );
        // 14
        glAccounts.add(
            new GL_Account__c(
                Name = '5050-Labor',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Labor',
                Sub_Type_2__c = 'Salary & Wages'
            )
        );
        // 15
        glAccounts.add(
            new GL_Account__c(
                Name = '6000-Marketing Expense',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Sales & Marketing',
                Sub_Type_2__c = 'Marketing Events'
            )
        );
        // 16
        glAccounts.add(
            new GL_Account__c(
                Name = '7000-Facilities Expense',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Facilities',
                Sub_Type_2__c = 'Rent'         
            )
        );
        // 17
        glAccounts.add(
            new GL_Account__c(
                Name = '7050-Telecommunications',
                Active__c = true,
                Type__c = 'Expense',
                Sub_Type_1__c = 'Facilities',
                Sub_Type_2__c = 'Utilities'            
            )
        );
        // 18
        glAccounts.add(
            new GL_Account__c(
                Name = '2030-Accrued Payroll',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Liabilities',
                Sub_Type_2__c = 'Current Liabilities'
            )
        );
        // 19
        glAccounts.add(
            new GL_Account__c(
                Name = '4900-Customer Payment Discounts',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Revenue',
                Sub_Type_1__c = 'Product Revenue',
                Sub_Type_2__c = 'Product Family 1'
            )
        );
        // 20
        glAccounts.add(
            new GL_Account__c(
                Name = '1500-Inventory',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'
            )
        );
        //=======================================================
        //========== New GL Accounts since 08/09/2016 ===========
        //=======================================================
        // 21
        glAccounts.add(
            new GL_Account__c(
                Name = '1400-Prepaid Expenses',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'
            )
        );
        // 22
        glAccounts.add(
            new GL_Account__c(
                Name = '1700-Accumulated Depreciation',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Fixed Assets'
            )
        );
        // 23
        glAccounts.add(
            new GL_Account__c(
                Name = '2500-Deferred Revenue',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Liabilities',
                Sub_Type_2__c = 'Current Liabilities'
            )
        );
        // 24
        glAccounts.add(
            new GL_Account__c(
                Name = '3900-Opening Balances',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Owners Equity',
                Sub_Type_2__c = 'Equity'
            )
        );
        // 25
        glAccounts.add(
            new GL_Account__c(
                Name = '6500-Depreciation Expense',
                Active__c = true,
                Bank__c = false,
                Type__c = 'Expense',
                Sub_Type_1__c = 'General & Administrative',
                Sub_Type_2__c = 'Software'
            )
        );

        // 26
        glAccounts.add(
            new GL_Account__c(
                Name = '3070-Equity Adjustments',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Owners Equity',
                Sub_Type_2__c = 'Equity'
            )
        );
        //=======================================================
        //========== New GL Accounts since 11/03/2021 ===========
        //=======================================================
        // 27
        glAccounts.add(
            new GL_Account__c(
                Name = '1450-Deferred Expenses',
                Active__c = true,
                Type__c = 'Balance Sheet',
                Sub_Type_1__c = 'Assets',
                Sub_Type_2__c = 'Current Assets'
            )
        );
        //=======================================================
        //========== New GL Accounts since 09/26/2023 ===========
        //=======================================================
        // 28, 29
        glAccounts.addAll(unappliedCashGLAccountsByNames().values());
        //=======================================================

        SFDCSecurityUtils.insertProxy(glAccounts);

        glAccountsExpense = new List<GL_Account__c>();
        // 0
        glAccountsExpense.add(
            new GL_Account__c(
                Name = '6050-Travel Expenses',
                Active__c = true,
                Type__c = 'Expense',
                Expense_Report_Name__c = 'Travel Expenses',
                Billing_Description__c = 'Travel Expenses',
                TM_Revenue_Conversion__c = glAccounts[11].Id,
                Sub_Type_1__c = 'Sales & Marketing',
                Sub_Type_2__c = 'Sales Travel'
            )
        );
        // 1
        glAccountsExpense.add(
            new GL_Account__c(
                Name = '6060-Meals and Entertainment',
                Active__c = true,
                Type__c = 'Expense',
                Used_In_Expense_Reports__c = true,
                Expense_Report_Name__c = 'Meals and Entertainment',
                Billing_Description__c = 'Meals and Entertainment',
                TM_Revenue_Conversion__c = glAccounts[11].Id,
                Sub_Type_1__c = 'Sales & Marketing',
                Sub_Type_2__c = 'Sales Travel'
            )
        );
        // 2
        glAccountsExpense.add(
            new GL_Account__c(
                Name = '6070-Mileage',
                Active__c = true,
                Type__c = 'Expense',
                Used_In_Expense_Reports__c = true,
                Expense_Report_Name__c = 'Mileage',
                Billing_Description__c = 'Mileage',
                Mileage_Account__c = true,
                Mileage_Rate__c = .52,
                TM_Revenue_Conversion__c = glAccounts[11].Id,
                Sub_Type_1__c = 'Sales & Marketing',
                Sub_Type_2__c = 'Sales Travel'           
            )
        );
        
        SFDCSecurityUtils.insertProxy(glAccountsExpense);

        billingFormats = new List<Billing_Format__c>();
        billingFormats.add(
            new Billing_Format__c(
                Name = 'Default Billing Product',
                Visualforce_PDF_Page__c = BILLING_PRODUCT_PDF_PAGE,
                Default_Email_Template__c = BILLING_EMAIL_TEMPLATE,
                Type__c = 'Billing',
                Image__c = '<img alt="Accounting Seed Logo" src="data:image/jpeg;base64,' + BILLING_FORMAT_IMAGE + '"></img>',
                Currency_Format__c = CURRENCY_FORMAT,
                Numeric_Format__c = NUMERIC_FORMAT
           )
        );
        
        billingFormats.add(
            new Billing_Format__c(
                Name = 'Default Billing Service',
                Visualforce_PDF_Page__c = BILLING_SERVICE_PDF_PAGE,
                Default_Email_Template__c = BILLING_EMAIL_TEMPLATE,
                Type__c = 'Billing',
                Image__c = '<img alt="Accounting Seed Logo" src="data:image/jpeg;base64,' + BILLING_FORMAT_IMAGE + '"></img>',
                Currency_Format__c = CURRENCY_FORMAT,
                Numeric_Format__c = NUMERIC_FORMAT
           )
        );
        
        billingFormats.add(
            new Billing_Format__c (
                Name = 'Default Billing Outstanding Statement',
                Visualforce_PDF_Page__c = OUTSTANDING_PDF_PAGE,
                Default_Email_Template__c = OUTSTANDING_EMAIL_TEMPLATE,
                Type__c = 'Outstanding Statement',
                Image__c = '<img alt="Accounting Seed Logo" src="data:image/jpeg;base64,' + BILLING_FORMAT_IMAGE + '"></img>',
                Currency_Format__c = CURRENCY_FORMAT,
                Numeric_Format__c = NUMERIC_FORMAT
           )
        );
        
        billingFormats.add(
            new Billing_Format__c (
                Name = 'Default Billing Activity Statement',
                Visualforce_PDF_Page__c = ACTIVITY_PDF_PAGE,
                Default_Email_Template__c = ACTIVITY_EMAIL_TEMPLATE,
                Type__c = 'Activity Statement',
                Image__c = '<img alt="Accounting Seed Logo" src="data:image/jpeg;base64,' + BILLING_FORMAT_IMAGE + '"></img>',
                Currency_Format__c = CURRENCY_FORMAT,
                Numeric_Format__c = NUMERIC_FORMAT
           )
        );

        SFDCSecurityUtils.insertProxy(billingFormats);

        //create default Ledgers: Transactional and Budget
        ledgers = new List<Ledger__c>();

        ledgers.add(
            new Ledger__c(
                Name = 'Actual',
                Type__c = 'Transactional',
                Default_Bank_Account__c = glAccounts[0].Id,
                Default_Billing_Format__c = billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = billingFormats[3].Id
            )
        );

        ledgers.add(new Ledger__c(Name = 'Budget', Type__c = 'Budget'));

        SFDCSecurityUtils.insertProxy(ledgers);

        //create tax settings and link with ledger
        createAndSetTaxSettings();

        //Default Transactional Ledger will be used as a default ledger for org default value of custom setting
        ledgerSettings = Ledger_Custom_Settings__c.getOrgDefaults();
        ledgerSettings.Ledger_Id__c = ledgers[0].Id;

        SFDCSecurityUtils.insertProxy(ledgerSettings);

        settings = new List<Accounting_Settings__c>();
        
        settings.add(
            new Accounting_Settings__c(
                Labor_GL_Account__c = glAccounts[18].Id,
                Payment_Discount_GL_Account__c = glAccounts[13].Id,
                Default_Ledger__c = ledgers[0].Id,
                Legacy_Default_Ledger__c = ledgers[0].Id,
                Ledger_Limit__c = 1,
                Default_Project_Task_Labor_GL_Account__c = glAccounts[14].Id,
                Enable_Product_Costing__c = true,
                Work_in_Process_GL_Account__c = glAccounts[3].Id,
                Vouchers_Payable_GL_Account__c = glAccounts[5].Id,
                Customer_Payment_Adjustment_GL_Account__c = glAccounts[19].Id,
                Prepaid_Expense_GL_Account__c = glAccounts[21].Id,
                Display_Billable_Flag_in_Time_Card_Entry__c = true,
                Default_Credit_GL_Account_Expense__c = glAccounts[27].Id,
                Default_Credit_GL_Account_Revenue__c = glAccounts[10].Id,
                Default_Debit_GL_Account_Revenue__c = glAccounts[23].Id,
                Credit_Memo_Default__c = 'Amount',
                Enable_Billing_Period_Sensitive_Aging__c=true,
                Enable_AP_Period_Sensitive_Aging__c=true
            )
        );

        AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = true;
        AccountingSettingsActions.isPreventUpdateOverride = true;
        SFDCSecurityUtils.insertProxy(settings);
        AccountingSettingsActions.isPreventUpdateOverride = false;
        AccountingSettingsActions.skipPreventUpdatePostSettingsValidations = false;
        
        Date acctDate = Date.newInstance(System.today().year(), System.today().month()-3, 1);
        acctPeriods = new List<Accounting_Period__c>();
        
        for (Integer i = 0; i < 15; i++) {
            acctPeriods.add(
                new Accounting_Period__c(
                    Name = String.valueOf(acctDate.year()) + '-' + (acctDate.month() > 9 ? String.valueOf(acctDate.month()) : '0' + String.valueOf(acctDate.month())),
                    Start_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), 1),
                    End_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), Date.daysInMonth(acctDate.year(),acctDate.month())),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                )
            );
            
            if (acctDate.month() == 12) {
                acctDate = Date.newInstance(acctDate.year()+1,1,1);
            }
            else {
                acctDate = acctDate.addMonths(1);
            }
        }
        
        SFDCSecurityUtils.insertProxy(acctPeriods);
        
        timeCardPeriods = new List<Time_Card_Period__c>();
        
        Date startOfWeek = acctPeriods[1].Start_Date__c.toStartOfWeek();
        
        if (startOfWeek.month() != acctPeriods[1].Start_Date__c.month()) {
            startOfWeek = startOfWeek + 7;
        }
        
        timeCardPeriods.add(
            new Time_Card_Period__c(
                Name = 'Week Beginning ' + DateTime.newInstance(startOfWeek.year(), startOfWeek.month(), startOfWeek.day()).format('yyyy-MM-dd'),
                Start_Date__c = startOfWeek,
                End_Date__c = startOfWeek + 7,
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );
        
        startOfWeek = startOfWeek + 7;
        timeCardPeriods.add(
            new Time_Card_Period__c(
                Name = 'Week Beginning ' + DateTime.newInstance(startOfWeek.year(), startOfWeek.month(), startOfWeek.day()).format('yyyy-MM-dd'),
                Start_Date__c = startOfWeek,
                End_Date__c = startOfWeek + 7,
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );
        
        startOfWeek = startOfWeek + 7;
        timeCardPeriods.add(
            new Time_Card_Period__c(
                Name = 'Week Beginning ' + DateTime.newInstance(startOfWeek.year(), startOfWeek.month(), startOfWeek.day()).format('yyyy-MM-dd'),
                Start_Date__c = startOfWeek,
                End_Date__c = startOfWeek + 7,
                Status__c = AccountingPeriodActions.OPEN_STATUS
            )
        );
        
        SFDCSecurityUtils.insertProxy(timeCardPeriods);

        setupAccountingPeriodRecurringTaskSampleData();
    }
}
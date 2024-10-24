public with sharing class BankSettingsHelper extends AbstractLWCHelper {
    @TestVisible
    private static final Decimal CASHINDEFAULTVALUE = 5;
    @TestVisible
    private static final Decimal CASHOUTDEFAULTVALUE = 60;
    @TestVisible
    private static final String CASHINRTDEFAULTVALUE = 'Cash Receipt';
    @TestVisible
    private static final String CASHOUTRTDEFAULTVALUE = 'Cash Disbursement';

    private static final Integer TRANSACTIONALLEDGERSCOUNT = LedgerService.getTransactionalLedgerCount();
    private static Ledger__c defaultLedger;
    private static Ledger__c legacyLedger;
    private static List<Ledger__c> transactionalLedgers;

    @TestVisible
    private static Map<string, BDC_Binding__c> activeBDCBindings;

    @TestVisible
    private static final String PROVIDERTYP = 'AbstractBDCRouter';

    @AuraEnabled
    public static BankSettingsWrapper getBankSettings() {
        BankSettingsWrapper newWrap = new BankSettingsWrapper();        
        return newWrap;
    }

    private static Map<String, AccountWrapper> getAccounts(Map<String, BDCFinancialInstitutionIdentity> mFIIdentity) {
        Map<String, AccountWrapper> acctMap = new Map<String, AccountWrapper>();

        for (BDC_Binding__c binding : activeBDCBindings.values()) {
            //instantiate service and options
            BDCService service = new bdcService();
            BDCServiceOptions options = new BDCServiceOptions();
            options.bdcBinding = service.getBDCBinding(binding.Name);
            options.bdcFinancialInstitutionIdentities = getFinancialIdentitiesForBinding(binding, mFIIdentity);
            //get accounts for FIs
            BDCServiceResult serviceResultAcct = service.getAccountsByIdentityIds(options);
            //if success populate acct wrapper
            if(serviceResultAcct.isSuccess){
                for (BDCAccount bdcAccount : serviceResultAcct.data.bdcAccounts) {
                    AccountWrapper acctWrapper = new AccountWrapper();
                    acctWrapper.bdcAccount = bdcAccount;
                    acctWrapper.fiaStatus = mFIIdentity.get(bdcAccount.financialInstitutionIdentity).status;
                    acctMap.put(bdcAccount.id, acctWrapper);
                }
            }
        }
        return acctMap;
    }

    private static Map<String, List<FinancialInstitutionWrapper>> getFinancialInstitutions(Map<String, BDCFinancialInstitutionIdentity> mFIIdentity) {
        Map<String, List<FinancialInstitutionWrapper>>  mFinancialInstitutitonBySource = new Map<String, List<FinancialInstitutionWrapper>> ();
        map<string, BDCFinancialInstitution> mFinancialInstitutitons = new map<string, BDCFinancialInstitution>();

        //used to recall user defined names for the identity (connection) from the access tokens
        Map<String, String> finInstIdenIdToName = PlaidBDCIdentityComparator.getIdentityIdToIdentityNameMap();

        BDCService service = new bdcService();
        BDCServiceOptions options = new BDCServiceOptions();
        //get financial institutions for each active binding type
        for (BDC_Binding__c binding : activeBDCBindings.values()) {
            List<FinancialInstitutionWrapper> financialInstitutions = new List<FinancialInstitutionWrapper>();
            options.bdcBinding = service.getBDCBinding(binding.Name);
            options.bdcFinancialInstitutionIdentities = getFinancialIdentitiesForBinding(binding, mFIIdentity);
            BDCServiceResult serviceResultFinInst = service.getFinancialInstitutions(options);
            if(serviceResultFinInst.isSuccess && serviceResultFinInst.data.bdcFinancialInstitutions != null && serviceResultFinInst.data.bdcFinancialInstitutions.size() > 0){
                //get map of financial institutions
                for(BDCFinancialInstitution finInst : serviceResultFinInst.data.bdcFinancialInstitutions){
                    mFinancialInstitutitons.put(finInst.Id, finInst);
                }

                //for each FI Identity populate the wrapper
                for(BDCFinancialInstitutionIdentity finInstIdentity : options.bdcFinancialInstitutionIdentities){
                    FinancialInstitutionWrapper fiw = new FinancialInstitutionWrapper();
                    //using safe operator becuase Yodlee has instances where a FII exists for a FI that does not.
                    fiw.id = mFinancialInstitutitons.get(finInstIdentity.financialInstitutionId)?.id;
                    fiw.name = mFinancialInstitutitons.get(finInstIdentity.financialInstitutionId)?.name;
                    fiw.fiaStatus = finInstIdentity.status;
                    fiw.financialInstitutionIdentityId = finInstIdentity.id;
                    fiw.identityName = finInstIdenIdToName.get(finInstidentity.id);
                    financialInstitutions.add(fiw);
                }
                mFinancialInstitutitonBySource.put(binding.Name, financialInstitutions);
            }
        }
        return mFinancialInstitutitonBySource;
    }

    private static Map<String, BDCFinancialInstitutionIdentity> getFinancialInstitutionIdentities(){
        Map<String, BDCFinancialInstitutionIdentity> mFIIdentity = new Map<String, BDCFinancialInstitutionIdentity>();
        BDCService service = new bdcService();
        BDCServiceOptions options = new BDCServiceOptions();
        //get financial institutions for each active binding type
        for (BDC_Binding__c binding : activeBDCBindings.values()) {
            options.bdcBinding = service.getBDCBinding(binding.Name);
            //get financial institutions identities
            BDCServiceResult serviceResultFinInst = service.getFinancialInstitutionIdentities(options);
            if(serviceResultFinInst.isSuccess){
                for(BDCFinancialInstitutionIdentity finInstIdentity : serviceResultFinInst.data.bdcFinancialInstitutionIdentities){
                    mFIIdentity.put(finInstIdentity.Id, finInstIdentity);
                }
            }
        }

        return mFIIdentity;
    }

    private static List<BDCFinancialInstitutionIdentity> getFinancialIdentitiesForBinding(BDC_Binding__c binding, Map<String, BDCFinancialInstitutionIdentity> mFIIdentity){
        List<BDCFinancialInstitutionIdentity> financialInstitutionIdentities = new List<BDCFinancialInstitutionIdentity>();
        for(BDCFinancialInstitutionIdentity finInstIdent : mFIIdentity.values()){
            if(finInstIdent.source == binding.Name){
                financialInstitutionIdentities.add(finInstIdent);
            }
        }

        return financialInstitutionIdentities;
    }

    @AuraEnabled
    public static SaveResponse deleteFinancialInstitutionIdentity(String bdcBindingDevName, String financialInstitutionIdentityId){
        try {
            BDCService service = new bdcService();

            BDCServiceOptions options = new BDCServiceOptions();
            options.bdcBinding = service.getBDCBinding(bdcBindingDevName);
            
            //create identity and set Id to pass to service via options
            BDCFinancialInstitutionIdentity FinInstIdent = new BDCFinancialInstitutionIdentity();
            FinInstIdent.Id = financialInstitutionIdentityId;
            options.bdcFinancialInstitutionIdentities = new List<BDCFinancialInstitutionIdentity>{FinInstIdent};

            BDCServiceResult serviceResult = service.deleteFinancialInstitutionIdentity(options);

            //If service result is unsuccesfull and error occured from API 
            if(serviceResult.isSuccess == false && serviceResult.errors != null) {
                throw new BDCService.BDCException(serviceResult.errors[0].detail);
            }
        } 

        catch (BDCService.BDCException ex) {
            return new SaveResponse(new List<String>{ex.getMessage()});
        }

        catch (exception ex) {
            String errMsg = ex.getMessage();
            errMsg = errMsg.right(errMsg.length() - errMsg.indexOf('EXCEPTION,') - 10);
            if (errMsg.contains('>')) {
                errMsg = errMsg.right(errMsg.length() - errMsg.indexOf('>') - 1);
                errMsg = errMsg.left(errMsg.indexOf('<'));
            }
            else {
                errMsg = errMsg.left(errMsg.indexOf(': ['));
            }
                return new SaveResponse(new List<String>{errMsg});
        }

        return new SaveResponse(NULL);
    }

    @AuraEnabled
    public static SaveResponse saveBankSettings(Boolean enableAdd,
                                                Boolean enableMatch,
                                                Decimal cashInDefaultMatchingSetting,
                                                Decimal cashOutDefaultMatchingSetting,
                                                String cashInDefaultSourceRecordType,
                                                String cashOutDefaultSourceRecordType,
                                                List<String> updatedGlams,
                                                Boolean prepopulateAccountInfo,
                                                Boolean singleFIA) {
        
        return save(enableAdd,
                    enableMatch,
                    cashInDefaultMatchingSetting,
                    cashOutDefaultMatchingSetting,
                    cashInDefaultSourceRecordType,
                    cashOutDefaultSourceRecordType,
                    updatedGlams,
                    prepopulateAccountInfo,
                    singleFIA);
    }

    public class SaveResponse {
        @AuraEnabled
        public Boolean isSuccess;
        @AuraEnabled
        public List<String> errors;
        
        public SaveResponse(List<String> errors) {
            this.isSuccess = errors == null || errors.size() == 0;
            this.errors = errors;        
        }
    }

    private class AccountWrapper {
        public BDCAccount bdcAccount;
        public String fiaStatus;
    }

    public class BankSettingsWrapper {
        @AuraEnabled
        public List<GLAMWrapper> glams;
        @AuraEnabled
        public Map<String, BDCFinancialInstitutionIdentity> mFinInstIdentity;
        @AuraEnabled
        public Map<String, List<FinancialInstitutionWrapper>> mFinancialInstitutitonBySource;
        @AuraEnabled
        public Boolean enableAdd;
        @AuraEnabled
        public Boolean enableMatch;
        @AuraEnabled
        public Decimal cashInDefaultMatchingSetting;
        @AuraEnabled
        public Decimal cashOutDefaultMatchingSetting;
        @AuraEnabled
        public String cashInDefaultSourceRecordType;
        @AuraEnabled
        public String cashOutDefaultSourceRecordType;
        @AuraEnabled
        public Boolean bdcEnabled;      
        @AuraEnabled
        public Boolean allowEdit;
        @AuraEnabled
        public Boolean prepopulateAccountInfo;

        /*************** ERROR VARIABLES FOR PAGE ***************/

        //These currencies have not been added and will be shown as errors on the page.
        //using only the bank ids without their source runs the low probability risk of duplicate bank ids across sources
        //     since only plaid is using foreign currency, the risk isn't there but it will be with additional implementations
        @AuraEnabled
        public Map<String, List<String>> bankToUnsupportedCurrencies = new Map<String, List<String>>();

        //Miscellaneous errors to be shown on the page when a bankSettingsWrapper should still be returned
        @AuraEnabled
        public List<String> pageErrors = new List<String>();

        /*************** END ERROR VARIABLES FOR PAGE ***************/

        private Map<String, GL_Account_Mapping__c> glamAccounts;
        private Map<String, AccountWrapper> accounts;     
        public Map<String, FinancialInstitutionWrapper> mFinancialInstitutions;
        // list used to store bdcaccount id to further check it with extisitng glam external id.
        private List<String> bdcaccountIds = new List<String>();   

        public BankSettingsWrapper () {
            getDefaultLedger();
            getLegacyLedger();
            getActiveBDCBindings();
            this.allowEdit = checkCRUDandFLS(); 
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();   
            this.enableAdd = acctSettings.Enable_Global_Automated_Add__c;
            this.enableMatch = acctSettings.Enable_Global_Automated_Match__c;
            this.cashInDefaultMatchingSetting = acctSettings.Cash_In_Default_Matching_Setting__c != NULL ? acctSettings.Cash_In_Default_Matching_Setting__c : CASHINDEFAULTVALUE;
            this.cashOutDefaultMatchingSetting = acctSettings.Cash_Out_Default_Matching_Setting__c != NULL ? acctSettings.Cash_Out_Default_Matching_Setting__c : CASHOUTDEFAULTVALUE;
            this.cashInDefaultSourceRecordType = String.isNotEmpty(acctSettings.Cash_In_Default_Source_Record_Type__c) ? acctSettings.Cash_In_Default_Source_record_Type__c : CASHINRTDEFAULTVALUE;
            this.cashOutDefaultSourceRecordType = String.isNotEmpty(acctSettings.Cash_Out_Default_Source_Record_Type__c) ? acctSettings.Cash_Out_Default_Source_Record_Type__c : CASHOUTRTDEFAULTVALUE;            
            this.bdcEnabled = checkBDCStatus();   
            this.glamAccounts = queryGlAccountMappings();  
            this.prepopulateAccountInfo = acctSettings.Pre_Populate_Account_Info__c;           

            this.pageErrors = new List<String>();
            this.bankToUnsupportedCurrencies = new Map<String, List<String>>();
            
            List<String> supportedCurrencies = new List<String>();
            if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
                for (SObject currencyType : DomainUtils.getCurrencyTypes()) {
                    supportedCurrencies.add((String) currencyType.get('IsoCode'));                                    
                }
            } else {
                supportedCurrencies.add(AbstractLWCHelper.CORPORATE_CURRENCY);
            }
            if (this.bdcEnabled) {
                
                  //get Financial Institution Identities
                  this.mFinInstIdentity = getFinancialInstitutionIdentities();

                  //set financial institutions from active agg providers
                  this.mFinancialInstitutitonBySource = getFinancialInstitutions(mFinInstIdentity);
  
                  //create/update GLAMs from accounts
                  this.glams = new List<GLAMWrapper>();

                if (mFinancialInstitutitonBySource.size() > 0) {
                    //set mFI used later for populating names
                    mFinancialInstitutions = new Map<String, FinancialInstitutionWrapper>();
                    for(List<FinancialInstitutionWrapper> lFiw : mFinancialInstitutitonBySource.values()){
                        for(FinancialInstitutionWrapper fiw : lFiw){
                            mFinancialInstitutions.put(fiw.financialInstitutionIdentityId, fiw);
                        }
                    }

                    //get Accounts from active agg providers
                    this.accounts = getAccounts(mFinInstIdentity);


                    //the following code block retrieves information on the currency of available ledgers
                    //the user will be notified if an account does not have a ledger in its currency available
                    Set<String> ledgerCurrencies = new Set<String>();
                    if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
                        if (transactionalLedgers == null) {
                            transactionalLedgers = LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers();
                        }
                        for (Ledger__c aTransLedger : transactionalLedgers) {
                            ledgerCurrencies.add(LedgerHandler.getLedgerCurrency(aTransLedger.id));
                        }
                    }

                    for (AccountWrapper account : this.accounts.values()) {
                        bdcaccountIds.add(account.bdcAccount.id);
                        if (glamAccounts.containsKey(account.bdcAccount.id)) {
                            GLAMWrapper glam = new GLAMWrapper(glamAccounts.get(account.bdcAccount.id), account, mFinancialInstitutions);

                            this.glams.add(glam);
                        } else {
                            GLAMWrapper glam = new GLAMWrapper(account, mFinancialInstitutions);
                            String noMultiCurrencyError = Label.MULTICURRENCY_NOT_ENABLED;
                            if (glam.currencyIsoCode != UserInfo.getDefaultCurrency() && !AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED
                                && !this.pageErrors.contains(noMultiCurrencyError)) {
                                pageErrors.add(noMultiCurrencyError);
                            }
                            if (!supportedCurrencies.contains(glam.currencyIsoCode)) {
                                if (this.bankToUnsupportedCurrencies.get(account.bdcAccount.financialInstitutionId) == null) {
                                    this.bankToUnsupportedCurrencies.put(account.bdcAccount.financialInstitutionId, new List<String>());
                                }
                                if (!this.bankToUnsupportedCurrencies.get(account.bdcAccount.financialInstitutionId).contains(glam.currencyIsoCode)) {
                                    this.bankToUnsupportedCurrencies.get(account.bdcAccount.financialInstitutionId).add(glam.currencyIsoCode); 
                                }
                            } else {

                                //If multicurrency is enabled and the currency is supported then add it
                                this.glams.add(glam);
                            }
                        }
                    }
                } else {
                    this.accounts = new Map<String, AccountWrapper>();
                }

                    GLAMWrapper glam;
                    /*
                      loop used to update Plaid glams with appropriate active status and fia status.  If there is a connection issue
                      with the FI we don't get a response back for the specified FI/access token and instead pull those glams from the db 
                      and mark them as inactive and set the appropriate status.  
                    */
                    List<GL_Account_Mapping__c> glamsToUpdate = new List<GL_Account_Mapping__c>();
                    for(GL_Account_Mapping__c bdcGlam : this.glamAccounts.values()){
                       if(activeBDCBindings.keySet().contains(bdcGlam.Source__c) && bdcGlam.inactive__c == false && 
                          bdcGlam.Source__c != YodleeBDCConverter.sourceApiName && !(bdcaccountIds.contains(bdcGlam.External_Id__c)))
                       {
                          bdcGlam.inactive__c = true; 
                          glam = new GLAMWrapper(bdcGlam, null, mFinancialInstitutions);
                          this.glams.add(glam);
                          glamsToUpdate.add(new GL_Account_Mapping__c(id = bdcGlam.Id, External_Id__c = glam.Id, 
                                      FIA_Status__c =  glam.fiaStatus));
                       }
                    }
                    
                    /* if to make sure that if glamsToUpdate size is greater than 0 then update fiasstatus as user input required.
                    */   
                    if(glamsToUpdate.size() > 0){
                        updateGLAMRecord(glamsToUpdate);
                    }
                    
                    this.glams.sort(); 

                if (this.allowEdit) {
                    reconcileGLAccountMappingRecords(this.accounts, this.glamAccounts);
                    updateGLAMNamesAndBalances(this.accounts, this.glamAccounts);
                }
            }          
        }
        
    }

    private static void updateGLAMRecord(List<GL_Account_Mapping__c> glamsToUpdate){
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
        SFDCSecurityUtils.updateProxy(glamsToUpdate);
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;
    }

    public class glamSaveItem {
        public String id;
        public String glAccountId;
        public String ledgerId;
        public String financialInstitutionId;
        public String financialInstitutionIdentityId;
        public String connectionName;
        public Date initialStartDate;
        public String name;
        public String financialInstitutionName;
        public String currencyIsoCode;
        public Decimal currentBalance;
        public Decimal availableBalance;
        public String fiaStatus;
        public String source;
        public DateTime lastRefreshedDate;
    }

    public class FinancialInstitutionWrapper {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String financialInstitutionIdentityId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String identityName;
        @AuraEnabled
        public String fiaStatus;

    }

    public class GLAMWrapper implements Comparable {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String financialInstitutionName;
        @AuraEnabled
        public String financialInstitutionId;
        @AuraEnabled
        public String financialInstitutionIdentityId;
        @AuraEnabled
        public String connectionName;
        @AuraEnabled
        public Datetime lastRefreshedDate;
        @AuraEnabled
        public Id glAccountId;
        @AuraEnabled
        public Id ledgerId;
        @AuraEnabled
        public Date maxStartDate;
        @AuraEnabled
        public Date initialStartDate;
        @AuraEnabled
        public String glAccountName;
        @AuraEnabled
        public String glAccountCurrencyIsoCode;
        @AuraEnabled
        public String ledgerName;
        @AuraEnabled
        public String ledgerCurrencyIsoCode;   
        @AuraEnabled
        public Boolean isLegacyLedger;
        @AuraEnabled
        public Boolean singleLedgerOrg;   
        @AuraEnabled
        public String currencyIsoCode;
        @AuraEnabled
        public Decimal currentBalance;
        @AuraEnabled
        public Decimal availableBalance;
        @AuraEnabled
        public String fiaStatus;
        @AuraEnabled
        public String fiaStatusClass;
        @AuraEnabled
        public Boolean fiaStatusFailed;
        @AuraEnabled
        public Boolean allowEditGLAM;
        @AuraEnabled
        public String source;

        private GL_Account_Mapping__c objGlam;

        public GLAMWrapper(GL_Account_Mapping__c glam, AccountWrapper account, Map<String, FinancialInstitutionWrapper> financialInstitutions) {
            objGlam = glam;
            setAccountFields(account, financialInstitutions);
            String currencyIsoCode = AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED ? (String) glam.get('CurrencyIsoCode') : AbstractLWCHelper.CORPORATE_CURRENCY;
            this.glAccountId = glam.GL_Account__c;
            this.glAccountName = glam.GL_Account__r.Name;
            this.connectionName = glam.Connection_Name__c;
            this.glAccountCurrencyIsoCode = currencyIsoCode;
            this.ledgerId = glam.Ledger__c != NULL ? glam.Ledger__c : legacyLedger.Id;
            this.ledgerName = glam.Ledger__c != NULL ? glam.Ledger__r.Name : legacyLedger.Name;
            this.ledgerCurrencyIsoCode = currencyIsoCode;
            this.isLegacyLedger = glam.Ledger__c != NULL ? false : true;
            this.initialStartDate = glam.Initial_Start_Date__c;
            this.lastRefreshedDate = glam.Last_Refreshed__c;
            this.currencyIsoCode = currencyIsoCode;           
        }

        public GLAMWrapper(AccountWrapper account, Map<String, FinancialInstitutionWrapper> financialInstitutions) {
            setAccountFields(account, financialInstitutions);
        }

        public Integer compareTo(Object compareTo) {
            GLAMWrapper compareToGLAM = (GLAMWrapper)compareTo;
            if (glAccountName == compareToGLAM.glAccountName) return 0;
            if (glAccountName > compareToGLAM.glAccountName)  return -1;            
            return 1;
        }

        private void setAccountFields(AccountWrapper account, Map<String, FinancialInstitutionWrapper> financialInstitutions) {
            this.id = account?.bdcAccount?.id != null ? account.bdcAccount.id : objGlam?.External_Id__c; 
            this.currencyIsoCode = account?.bdcAccount?.bdcCurrencyISOCode != null ? account.bdcAccount.bdcCurrencyISOCode : AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED ? (String) objGlam.get('CurrencyIsoCode') : AbstractLWCHelper.CORPORATE_CURRENCY;
            this.name = (account != null) ? formatAccountName(account) : objGlam?.AcctSeed__Account_Name__c;
            this.financialInstitutionName = financialInstitutions?.get(account?.bdcAccount?.financialInstitutionIdentity)?.name != null ?  financialInstitutions.get(account.bdcAccount.financialInstitutionIdentity).name : objGlam?.AcctSeed__Financial_Institution__c;
            this.financialInstitutionIdentityId = account?.bdcAccount?.financialInstitutionIdentity != null ?  account.bdcAccount.financialInstitutionIdentity : objGlam?.AcctSeed__Financial_Institution_Id__c; 
            this.financialInstitutionId = financialInstitutions?.get(account?.bdcAccount?.financialInstitutionIdentity)?.id != null ? financialInstitutions.get(account.bdcAccount.financialInstitutionIdentity).id : objGlam?.AcctSeed__Financial_Institution_Id_Actual__c; 
            this.initialStartDate = Date.today().addMonths(-3); 
            for (BDC_Access_tokens__c aToken : BDC_Access_tokens__c.getAll().values()) {
                if (aToken.Financial_Institution_Identity_Id__c == this.financialInstitutionIdentityId) {
                    this.connectionName = aToken.Identity_Name__c;
                    break;
                }
            }
            this.currentBalance = account?.bdcAccount?.currentBalance != null ? account.bdcAccount.currentBalance : objGlam?.AcctSeed__Current_Balance__c;
            this.availableBalance = account?.bdcAccount?.availableBalance != null ? account.bdcAccount.availableBalance : objGlam?.AcctSeed__Available_Balance__c;  
            this.fiaStatus = account != null ? getFIAStatusMessage(account) : BDCService.USER_INPUT_REQUIRED_ERROR_MSG;
            this.singleLedgerOrg = TRANSACTIONALLEDGERSCOUNT < 2;
            if (defaultLedger != NULL) {
                if (!AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED || 
                        (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED && (String)defaultLedger.get('CurrencyIsoCode') == this.currencyIsoCode)) {
                    this.ledgerId = this.singleLedgerOrg ? defaultLedger.Id : null;
                    this.ledgerName = this.singleLedgerOrg ? defaultLedger.Name : null;
                }
            }

            this.fiaStatusClass = this.fiaStatus != BDCService.NO_ACTION_REQUIRED_MSG ? 'slds-text-color_error' : 'slds-text-color_success';
            this.fiaStatusFailed = !String.isEmpty(this.fiaStatus) 
                                    && this.fiaStatus != BDCService.NO_ACTION_REQUIRED_MSG 
                                    ? true 
                                    : false;
            if (!this.singleLedgerOrg) {
                this.singleLedgerOrg = this.fiaStatusFailed;
            }
            this.allowEditGLAM = !this.fiaStatusFailed;
            this.maxStartDate = Date.today().addDays(1); 
            this.source = account?.bdcAccount?.source != null ? account.bdcAccount.source : objGlam?.Source__c;
        }
    }

 /*
    * Puts the account name in the following format when each value is available
    * officialName (nickname) - maskedAccountNumber
    * Omits Information based on available fields. See unit tests for examples.
    */
    private static String formatAccountName(AccountWrapper account) {
        return BankSettingsHelper.buildAccountNameString(account.bdcAccount.name, account.bdcAccount.nickname, account.bdcAccount.maskedAccountNumber);
    }

    //private method to make testing easy. (no need to construct an AccountWrapper)
    @testVisible
    private static String buildAccountNameString(String officialName, String nickname, String maskedAccountNumber) {
        String fullAccountName = '';
        Boolean includeParens = true;
        Set<String> invalidValues = new Set<String>{null, '', 'null'};
        if (!invalidValues.contains(officialName)) {
            fullAccountName += officialName;
        } else {
            includeParens = false;
        }
        if (!invalidValues.contains(nickname)) {
            if (includeParens) {
                fullAccountName += ' (' + nickname + ')';
            } else {
                fullAccountName += nickname;
            }
        }
        if (!invalidValues.contains(maskedAccountNumber)) {
            if (fullAccountName != '') {
                fullAccountName += ' - ' + maskedAccountNumber;
            } else {
                fullAccountName = maskedAccountNumber;
            }
        }
        if (fullAccountName == '') {
            fullAccountName = Label.NO_ACCOUNT_INFO;
        }
        return fullAccountName;
    }

    private static Ledger__c getDefaultLedger() {
        if (defaultLedger == NULL) {
            defaultLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(LedgerHandler.getLedgerId());            
        }
        return defaultLedger;        
    }

    public static Map<String, BDC_Binding__c> getActiveBDCBindings(){
        if(activeBDCBindings == NULL){
            activeBDCBindings = new Map<string, BDC_Binding__c>();

            for(BDC_Binding__c binding : (List<BDC_Binding__c>) fetchAggregationProviders()){ 
                if(binding.Is_Active__c){
                    activeBDCBindings.put(binding.Name, binding);
                }
            }
        }
      
        return activeBDCBindings;
    }

    private static String getFIAStatusMessage(AccountWrapper account) {
        String bdcStatus = account.fiaStatus;
        return bdcStatus == BDCService.PROVIDER_STATUS_USER_INPUT_REQUIRED
                ? BDCService.USER_INPUT_REQUIRED_ERROR_MSG
                : bdcStatus == BDCService.PROVIDER_STATUS_FAILED
                ? BDCService.FAILED_ERROR_MSG
                : BDCService.NO_ACTION_REQUIRED_MSG;     
    }

    private static Ledger__c getLegacyLedger() {
        if (legacyLedger == NULL) {
            legacyLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(LedgerHandler.getLegacyDefaultLedgerId());
        }
        return legacyLedger;
    }

    private static Boolean checkBDCStatus() {
        Boolean isAnyBDCProviderActive = false;
        try {
            for(BDC_Binding__c csBinding : activeBDCBindings.values()){
                if(csBinding.Is_Active__c){
                    isAnyBDCProviderActive = true;
                }
            }
        } catch (Exception ex) {
            isAnyBDCProviderActive = false;
        }

        return isAnyBDCProviderActive;
    }

    private static Boolean checkCRUDandFLS() {
        try {            
            SFDCSecurityUtils.checkInsert(GL_Account_Mapping__c.getSObjectType(), new List<String>{
                'GL_Account__c',
                'Ledger__c',
                'Financial_Institution__c',
                'Financial_Institution_Id__c',
                'Account_Name__c',
                'Initial_Start_Date__c',
                'Source__c'
            });
            
            SFDCSecurityUtils.checkUpdate(Accounting_Settings__c.getSObjectType(), new List<String>{
                'Enable_Global_Automated_Add__c',
                'Enable_Global_Automated_Match__c',
                'Cash_In_Default_Matching_Setting__c',
                'Cash_Out_Default_Matching_Setting__c',
                'Cash_In_Default_Source_Record_Type__c',
                'Cash_Out_Default_Source_Record_Type__c'
            });

            //Reset FLS Inspector
            SFDCSecurityUtils.flsInspector.clearInspectionResultMap();

            return true;
        } catch (Exception ex) {
            return false;
        }
    }

    private static SaveResponse save(   Boolean enableAdd,
                                        Boolean enableMatch,
                                        Decimal cashInDefaultMatchingSetting,
                                        Decimal cashOutDefaultMatchingSetting,
                                        String cashInDefaultSourceRecordType,
                                        String cashOutDefaultSourceRecordType,
                                        List<String> updatedGlams,
                                        Boolean prepopulateAccountInfo,
                                        Boolean singleFIA) {
        Savepoint sp = Database.setSavepoint();     
        Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
         /* field Single_FIA_per_Bank_Account__c need to update before GLAM record insert/update
           so that GL_ACCount_mapping_action trigger can run on this field value
           to map unique or duplicate GL accounts to each bank account
        */
        acctSettings.Single_FIA_per_Bank_Account__c = singleFIA;
        SFDCSecurityUtils.updateCheckCRUDAndFLS(acctSettings, new List<String>{
            'Single_FIA_per_Bank_Account__c'
    });
        SaveResponse srGLAMs = saveGLAMs(updatedGlams);
        if (srGLAMs.isSuccess) {
            SaveResponse srAccountingSettings = saveAccountingSettings(  enableAdd, 
                                            enableMatch, 
                                            cashInDefaultMatchingSetting, 
                                            cashOutDefaultMatchingSetting, 
                                            cashInDefaultSourceRecordType, 
                                            cashOutDefaultSourceRecordType,
                                            prepopulateAccountInfo,
                                            acctSettings);
            if (!srAccountingSettings.isSuccess) {
                Database.rollback(sp);
            }
            return srAccountingSettings;
        } else {
            return srGLAMs;
        }              
    }

    private static SaveResponse saveGLAMs(List<String> updatedGlams) {
        Savepoint sp = Database.setSavepoint();     
        if (updatedGlams.size() > 0) {
            try {
                Map<String, glamSaveItem> saveItems = new Map<String, glamSaveItem>();
                for (String jsonData : updatedGlams) {
                    glamSaveItem item = (glamSaveItem) JSON.deserialize(jsonData, glamSaveItem.class);
                    saveItems.put(item.id, item);            
                }
                List<GL_Account_Mapping__c> glamsToCreate = new List<GL_Account_Mapping__c>();

                //get any existing GLAMs for the passed in GLAM records, clone them and then delete them
                Map<String, GL_Account_Mapping__c> glams = queryGlAccountMappings(saveItems.keySet());
                List<GL_Account_Mapping__c> existingGLAMs = glams.values();
                for (GL_Account_Mapping__c glam : existingGLAMs) {
                    if (saveItems.get(glam.External_Id__c).glAccountId != NULL) {
                        glam.Ledger__c = saveItems.get(glam.External_Id__c).ledgerId;
                        glam.GL_Account__c = saveItems.get(glam.External_Id__c).glAccountId; 
                        glam.Account_Name__c = saveItems.get(glam.External_Id__c).name;
                        glam.Financial_Institution__c = saveItems.get(glam.External_Id__c).financialInstitutionName;  
                        glam.Financial_Institution_Id__c = saveItems.get(glam.External_Id__c).financialInstitutionIdentityId; 
                        glam.Financial_Institution_Id_Actual__c = saveItems.get(glam.External_Id__c).financialInstitutionId; 
                        glam.Connection_Name__c = saveItems.get(glam.External_Id__c).connectionName;
                        glam.Initial_Start_Date__c = saveItems.get(glam.External_Id__c).initialStartDate;
                        glam.Source__c = saveItems.get(glam.External_Id__c).source;
                        glam.Available_Balance__c = saveItems.get(glam.External_Id__c).availableBalance;
                        glam.Current_Balance__c = saveItems.get(glam.External_Id__c).currentBalance;
                        glam.FIA_Status__c = saveItems.get(glam.External_Id__c).fiaStatus;
                        glam.Last_Refreshed__c = saveItems.get(glam.External_Id__c).lastRefreshedDate;
                    }
                }
            
                if (existingGLAMs.size() > 0) {
                    GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
                    SFDCSecurityUtils.updateCheckCRUDAndFLS(existingGLAMs, new List<String>{
                        'GL_Account__c',
                        'Ledger__c',
                        'Account_Name__c',
                        'Financial_Institution__c',
                        'Financial_Institution_Id__c',
                        'Financial_Institution_Id_Actual__c',
                        'Connection_Name__c',
                        'Initial_Start_Date__c',
                        'Source__c',
                        'Available_Balance__c',
                        'Current_Balance__c'
                    });
                    GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;
                }

                //handle any new GLAMs that need to be created            

                //create a map of identity id to the existing connection name
                Map<String, String> finInstIdToConnectionName = new Map<String, String>();
                for (BDC_Access_tokens__c aToken : BDC_Access_tokens__c.getAll().values()) {
                        finInstIdToConnectionName.put(aToken.Financial_Institution_Identity_Id__c, aToken.Identity_Name__c);
                }
                for (glamSaveItem item : saveItems.values()) {
                    if (!glams.containsKey(item.id) && item.glAccountId != NULL && item.glAccountId != '') {
                        GL_Account_Mapping__c glam = new GL_Account_Mapping__c(
                            External_Id__c = item.id,
                            GL_Account__c = item.glAccountId,
                            Ledger__c = item.ledgerId,
                            Account_Name__c = item.name,
                            Financial_Institution__c = item.financialInstitutionName,
                            Financial_Institution_Id__c = item.financialInstitutionIdentityId,
                            Financial_Institution_Id_Actual__c = item.financialInstitutionId,
                            Initial_Start_Date__c = item.initialStartDate,
                            Source__c = item.source,
                            Available_Balance__c = item.availableBalance,
                            Current_Balance__c = item.currentBalance,
                            Last_Refreshed__c = item.lastRefreshedDate
                        );
                        if (finInstIdToConnectionName.get(item.financialInstitutionIdentityId) != null) {
                            glam.Connection_Name__c = finInstIdToConnectionName.get(item.financialInstitutionIdentityId);

                        }

                        if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
                            glam.put('CurrencyIsoCode', item.currencyIsoCode);
                        }
                        glamsToCreate.add(glam);
                    }
                }
                if (glamsToCreate.size() > 0) {
                    SFDCSecurityUtils.insertCheckCRUDAndFLS(glamsToCreate, new List<String>{
                        'GL_Account__c',
                        'Ledger__c',
                        'Account_Name__c',
                        'Financial_Institution__c',
                        'Financial_Institution_Id__c',
                        'Initial_Start_Date__c',
                        'Source__c',
                        'Available_Balance__c',
                        'Current_Balance__c'
                    });
                }
                return new SaveResponse(NULL);    
            } catch (Exception ex) {
                String errMsg = ex.getMessage();
                errMsg = errMsg.right(errMsg.length() - errMsg.indexOf('EXCEPTION,') - 10);
                if (errMsg.contains('>')) {
                    errMsg = errMsg.right(errMsg.length() - errMsg.indexOf('>') - 1);
                    errMsg = errMsg.left(errMsg.indexOf('<'));
                }
                else {
                    errMsg = errMsg.left(errMsg.indexOf(': ['));
                }
                Database.rollback(sp);
                return new SaveResponse(new List<String>{errMsg});
            }  
        } else {
            return new SaveResponse(NULL); 
        }
    }

    private static SaveResponse saveAccountingSettings(
                                                        Boolean enableAdd,
                                                        Boolean enableMatch,
                                                        Decimal cashInDefaultMatchingSetting,
                                                        Decimal cashOutDefaultMatchingSetting,
                                                        String cashInDefaultSourceRecordType,
                                                        String cashOutDefaultSourceRecordType,
                                                        Boolean prepopulateAccountInfo,
                                                        Accounting_Settings__c acctSettings) {
        Savepoint sp = Database.setSavepoint(); 
        try {
            
            acctSettings.Enable_Global_Automated_Add__c = enableAdd;
            acctSettings.Enable_Global_Automated_Match__c = enableMatch;
            acctSettings.Cash_In_Default_Matching_Setting__c = cashInDefaultMatchingSetting;
            acctSettings.Cash_Out_Default_Matching_Setting__c = cashOutDefaultMatchingSetting;
            acctSettings.Cash_In_Default_Source_Record_Type__c = cashInDefaultSourceRecordType;
            acctSettings.Cash_Out_Default_Source_Record_Type__c = cashOutDefaultSourceRecordType; 
            acctSettings.Pre_Populate_Account_Info__c = prepopulateAccountInfo;

            SFDCSecurityUtils.updateCheckCRUDAndFLS(acctSettings, new List<String>{
                    'Enable_Global_Automated_Add__c',
                    'Enable_Global_Automated_Match__c',
                    'Cash_In_Default_Matching_Setting__c',
                    'Cash_Out_Default_Matching_Setting__c',
                    'Cash_In_Default_Source_Record_Type__c',
                    'Cash_Out_Default_Source_Record_Type__c',
                    'Pre_Populate_Account_Info__c'
            });
            AccountingSettingsHandler.resetAccountingSettings();
            return new SaveResponse(NULL);            
        } catch (Exception ex) {
            String errMsg = ex.getMessage();
            errMsg = errMsg.right(errMsg.length() - errMsg.indexOf('EXCEPTION,') - 10);
            if (errMsg.contains('>')) {
                errMsg = errMsg.right(errMsg.length() - errMsg.indexOf('>') - 1);
                errMsg = errMsg.left(errMsg.indexOf('<'));
            }
            else {
                errMsg = errMsg.left(errMsg.indexOf(': ['));
            }
            Database.rollback(sp);
            return new SaveResponse(new List<String>{errMsg});
        }  
    }

    private static Map<String, GL_Account_Mapping__c> queryGlAccountMappings() {
        return queryGlAccountMappings(NULL);
    }

    private static Map<String, GL_Account_Mapping__c> queryGlAccountMappings(Set<String> accountIds) {
        Map<String, GL_Account_Mapping__c> retVal = new Map<String, GL_Account_Mapping__c>();
        List<String> queryFields = new List<String> {
            'Id',
            'Name',
            'Account_Name__c',
            'Connection_Name__c',
            'Available_Balance__c',
            'Current_Balance__c',
            'External_Id__c',
            'Financial_Institution__c',
            'Financial_Institution_Id__c',
            'Financial_Institution_Id_Actual__c',
            'GL_Account__r.Name',
            'GL_Account__c',
            'Initial_Start_Date__c',
            'Last_Refreshed__c',
            'Ledger__r.Name',
            'Ledger__c',
            'Inactive__c',
            'Source__c',
            'FIA_Status__c'
        };

        if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = '';
        if (accountIds != NULL && accountIds.size()> 0) {
            queryCondition = 'External_Id__c IN :accountIds OR Financial_Institution_Id__c in :accountIds';
        } else {
            queryCondition = 'External_Id__c != NULL';
        }        

        SOQLBuilder theQuery = new SOQLBuilder(GL_Account_Mapping__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        for (GL_Account_Mapping__c glam :  (List<GL_Account_Mapping__c>)Database.query(theQuery.toSOQL())) {
            retVal.put(glam.External_Id__c, glam);
        }
        return retVal;
    }

    private static void reconcileGLAccountMappingRecords(Map<String, AccountWrapper> accounts, Map<String, GL_Account_Mapping__c> glams) {
        List<GL_Account_Mapping__c> glamsToUpdate = new List<GL_Account_Mapping__c>();
        for (GL_Account_Mapping__c glam : glams.values()) {
            if (activeBDCBindings.keySet().contains(glam.Source__c) || glam.Source__c == NULL){
                //if GLAM ext id is returned from BDC Service then set the existing glam to active and update source
                if (accounts.keySet().contains(glam.External_Id__c) && glam.Inactive__c == true) {
                    glam.Inactive__c = false;
                    //get source from BDCAccount in map/wrapper
                    glam.Source__c = glam.Source__c == NULL ? accounts.get(glam.External_Id__c).BDCAccount.Source : glam.Source__c;
                    glamsToUpdate.add(glam);
                }
                if (!accounts.keySet().contains(glam.External_Id__c) && glam.Inactive__c == false) {
                    glam.Inactive__c = true;
                    //get source from BDCAccount in map/wrapper
                    glam.Source__c = glam.Source__c == NULL ? accounts.get(glam.External_Id__c).BDCAccount.Source : glam.Source__c;
                    glamsToUpdate.add(glam);
                }
            }
        }
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
        SFDCSecurityUtils.updateProxy(glamsToUpdate);
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;
    }

    private static void updateGLAMNamesAndBalances(Map<String, AccountWrapper> accounts, Map<String, GL_Account_Mapping__c> glams) {
        Map<String, GL_Account_Mapping__c> glamsToUpdate = new Map<String, GL_Account_Mapping__c>();
        for (GL_Account_Mapping__c glam : glams.values()) {
            if (accounts.containsKey(glam.External_Id__c)) {
                AccountWrapper account = accounts.get(glam.External_Id__c);
                String bdcAccountName = formatAccountName(account);
                if (glam.Account_Name__c != bdcAccountName) {
                    glam.Account_Name__c = bdcAccountName;
                    glamsToUpdate.put(glam.External_Id__c, glam);
                }

                if (glam.Available_Balance__c != account.bdcAccount.availableBalance) {
                    glam.Available_Balance__c = account.bdcAccount.availableBalance;   
                    glamsToUpdate.put(glam.External_Id__c, glam);
                }
                if (glam.Current_Balance__c != account.bdcAccount.currentBalance) {
                    glam.Current_Balance__c = account.bdcAccount.currentBalance;
                    glamsToUpdate.put(glam.External_Id__c, glam);
                } 

                if (glam.FIA_Status__c != getFIAStatusMessage(account)) {
                    glam.FIA_Status__c = getFIAStatusMessage(account);
                    glamsToUpdate.put(glam.External_Id__c, glam);
                }               
            }
        }
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
        SFDCSecurityUtils.updateProxy(glamsToUpdate.values());
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;
    }


    /**
    * This method is used used to fetch all aggregation provider of type {PROVIDERTYP} configured in Binding custom metadata
    */
    @AuraEnabled
    public static Object fetchAggregationProviders(){
        return DomainUtils.getAllBindingsByProviderType(PROVIDERTYP);
    }

    /**
    * This method is used used to register and deregister providers
    */
    @AuraEnabled
    public static Object registerDeregisterProviders(String providerJSON){
        try {
            Set<String> deRegProviders = new Set<String>();
            List<providersResponse> providerResp = (List<providersResponse>) JSON.deserialize(providerJSON, List<providersResponse>.class);

            List<BDCServiceResult> results = new List<BDCServiceResult>();
            //currently this list will only hold the metadata that needs to be register/deRegister
            List<CustomSettingConfig> metaDataUpdates = new List<CustomSettingConfig>();
            
            for(providersResponse providers : providerResp){
                if(providers.registerProvider){                   
                    /* this if is a legacy issue for Yodlee because registration process is only for Yodlee
                       and user is already registered then second time we are checking if user exist then directly 
                       make custom setting active.  
                       But for Plaid there is no registration process so custom setting can directly active. 
                    */
                    YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
                    if((providers.binding.Name == YodleeBDCConverter.sourceApiName && yodleeConnect.getuserDetails().isSuccess) || providers.binding.Name == 'Plaid'){ // no need to again register make it directly active
                        metaDataUpdates.add(new CustomSettingConfig(providers.binding.Name, new Map<String, Object>{'Is_Active__c'=>true})); 
                    }else{
                        // else is also only for yodlee because user has to register itself for use yodlee
                        results.add(yodleeConnect.registerUser());
                    }
                }
                else if(providers.deRegisterProvider){
                    //add name of provider that needs to deregister in set so that it will further used for inactive its related glams
                    deRegProviders.add(providers.binding.Name);
                    metaDataUpdates.add(new CustomSettingConfig(providers.binding.Name, new Map<String, Object>{'Is_Active__c'=>false}));
                }
            }
            return processServiceResponse(results, metaDataUpdates, deRegProviders);
        } catch (Exception e) {
            throw new BDCService.BDCException(e.getMessage()+' '+e.getLineNumber());
        }
    }
    
    /**
    * This method is used used for process service result while register user to filterout failed and success providers to register
    */
    public static Object processServiceResponse(List<BDCServiceResult> results, List<CustomSettingConfig> metaDataUpdates, Set<String> deRegProviders){
        Boolean metaDataUpdateSuccess = false;
        ResponseData resp = new ResponseData();
        resp.serviceFaultProviders = new List<String>();

        //Yodlee makes a callout to register users this is handling the results of that callout
        for(BDCServiceResult serviceResult : results){
            if(serviceResult.isSuccess == true){
                // add metadatas that needs to be register 
                metaDataUpdates.add(new CustomSettingConfig(YodleeBDCConverter.sourceApiName, new Map<String, Object>{'AcctSeed__Is_Active__c'=>true}));
            }else{
                // add failed provider here
                // here service is only for yodlee so if success false(i.e, any issue in service) then add yodlee directly
                resp.serviceFaultProviders.add(YodleeBDCConverter.sourceApiName);
            }
        }
        if(metaDataUpdates.size() > 0){
            metaDataUpdateSuccess = (Boolean) DomainUtils.updateCustomSettingdata(metaDataUpdates); 
        }
        
        // this if to make sure that if metadata update is successful then inactive glam records based on source of deregistered provider
        if(metaDataUpdateSuccess && deRegProviders.size() > 0){
            inActiveGlamRecords(deRegProviders); 
        }
        
        // this if to make sure that if any provider that is going to register but failed due to service error show an error message
        if(resp.serviceFaultProviders.size() > 0){
            resp.faultMessage = Label.REG_DEREG_ERROR_MSG.replace('**', String.join(resp.serviceFaultProviders, ',')+'.');
        }
        resp.isSuccess = true;
        return JSON.serializePretty(resp);
    }
   
    /**
    * This method is used used for make Glam records inactive corrsopond to inactive binding records after successfully deregister the providers
    */
    public static void inActiveGlamRecords(Set<String> deRegProviders){
        List<GL_Account_Mapping__c> BDCData = new List<GL_Account_Mapping__c>();
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
        List<String> queryFields = new List<String> {
            'Id',
                'Inactive__c',
                'Source__c'
                };
                    
                    SOQLBuilder theQuery = new SOQLBuilder(GL_Account_Mapping__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition('Inactive__c = false AND Source__c IN: deRegProviders')
            .setLimit(50000);
        
        for(GL_Account_Mapping__c glam : (List<GL_Account_Mapping__c>)Database.query(theQuery.toSOQL())){
            glam.Inactive__c = true;
            BDCData.add(glam);
        }
        SFDCSecurityUtils.updateProxy(BDCData);
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;
    }

    /**
     * class used for store the data coming from LWC like binding records of register/deregister providers
     */
    public with sharing class providersResponse{
        public Boolean registerProvider;
        public Boolean deRegisterProvider;
        public BDC_Binding__c binding;
    }

    /**
     * class used for store response after register/deregister succesfully and returned to LWC for further processing
     */

    public with sharing class ResponseData{
        public Boolean isSuccess;
        public List<String> serviceFaultProviders;
        public String faultMessage;
    }
}
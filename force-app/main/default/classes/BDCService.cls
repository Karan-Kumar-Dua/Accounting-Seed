global with sharing class BDCService {

    global class BDCException extends Exception{}

    global static final String PROVIDER_STATUS_USER_INPUT_REQUIRED = 'USER_INPUT_REQUIRED';
    global static final String USER_INPUT_REQUIRED_ERROR_MSG = Label.COMMON_USER_AUTHENTICATION_REQ;
    global static final String PROVIDER_STATUS_FAILED = 'FAILED';
    global static final String FAILED_ERROR_MSG = Label.ERR_FIA_FAILED;
    global static final String NO_ACTION_REQUIRED_MSG = Label.COMMON_CONN_SUCCESS_NO_ACTION_REQUIRED_MSG;
    global static final Integer DEFAULT_START_DATE_OFFSET_IN_DAYS = 90;
    global static final Integer GLAM_PAGE_SIZE = 100;
    global static final Integer REFRESH_OFFSET = 14;

    @TestVisible
    private static final String ERR_BDC_MISSING_OPTIONS = Label.ERR_BDC_MISSING_OPTIONS;
    @TestVisible
    private static final String ERR_BDC_MISSING_ROUTER = Label.ERR_BDC_MISSING_ROUTER;
    @TestVisible
    private static final String ERR_BDC_MISSING_FROM_DATE = Label.ERR_BDC_MISSING_FROM_DATE;
    @TestVisible
    private static final String ERR_BDC_MISSING_TO_DATE = Label.ERR_BDC_MISSING_TO_DATE;
    @TestVisible
    private static final String ERR_BDC_MISSING_ACCOUNT_IDS = Label.ERR_BDC_MISSING_ACCOUNT_IDS;
    @TestVisible
    private static final String ERR_BDC_MISSING_FI_IDS = Label.ERR_BDC_MISSING_FI_IDS;
    @TestVisible
    private static final String ERR_BDC_MISSING_FI_IDENTITY_IDS = Label.ERR_BDC_MISSING_FI_IDENTITY_IDS;
    @TestVisible
    private static final String ERR_BDC_INVALID_DATE_RANGE = Label.ERR_BDC_INVALID_DATE_RANGE;
    @TestVisible
    private static final String ERR_BDC_INVALID_BINDING_NAME = Label.ERR_BDC_INVALID_BINDING_NAME;
    

    private APIServiceContext.APIServiceEntry serviceEntry;
   
    @TestVisible
    private BDCRouterFactory routerFactory;

    @TestVisible
    private AbstractBDCRouter router;

    @TestVisible
    private List<HttpResponse> connectorResponses;

    @TestVisible
    private BDCDataModel dataModel;


    global BDCService() {
        this.routerFactory = new BDCRouterFactory();
        this.serviceEntry = new APIServiceContext.APIServiceEntry();
    }


    //GLOBAL METHODS*******************************************************************


        global BDCServiceResult deleteFinancialInstitutionIdentity(BDCServiceOptions options){
            if (options == null ) {
                throw new BDCException(ERR_BDC_MISSING_OPTIONS);
            }
            ServiceResult validationResult = APIServiceContext.validateServiceContext(this.serviceEntry);
            if (!validationResult.isSuccess) {
                throw new BDCException(String.join(validationResult.errors, '; '));
            }
            return this.deleteFinInstViaRouter(options);

        }
    
        //get the BDC Binding metadata record by developer name string
        global BDC_Binding__c getBDCBinding(String BindingName){
            if(BindingName == NULL){
                throw new BDCException(ERR_BDC_INVALID_BINDING_NAME);
            }
            BDCRouterFactory routerFactory = new BDCRouterFactory();
            BDC_Binding__c binding = routerFactory.mBDCAggregationServiceRouters.get(BindingName.toLowerCase());
            if(binding == NULL || !binding.Is_Active__c){
                throw new BDCException(ERR_BDC_MISSING_ROUTER);
            }
            return binding;
        }

        //get all BDC Binding metadata records
        global list<BDC_Binding__c> getBDCBindings(){
            BDCRouterFactory routerFactory = new BDCRouterFactory();
            return routerFactory.mBDCAggregationServiceRouters.values();
        }

        global BDCServiceResult getTransactions(BDCServiceOptions options){
            if (options == null ) {
                throw new BDCException(ERR_BDC_MISSING_OPTIONS);
            }
            ServiceResult validationResult = APIServiceContext.validateServiceContext(this.serviceEntry);
            if (!validationResult.isSuccess) {
                throw new BDCException(String.join(validationResult.errors, '; '));
            }
            return this.getTransactionsViaRouter(options);
        }

        global List<BDCServiceResult> getAllTransactionsBulk(){           
            ServiceResult validationResult = APIServiceContext.validateServiceContext(this.serviceEntry);
            if (!validationResult.isSuccess) {
                throw new BDCException(String.join(validationResult.errors, '; '));
            }
            return this.getAllTransactionsBulkViaRouters();
        }

        global BDCServiceResult getFinancialInstitutions(BDCServiceOptions options){
            if (options == null ) {
                throw new BDCException(ERR_BDC_MISSING_OPTIONS);
            }
            ServiceResult validationResult = APIServiceContext.validateServiceContext(this.serviceEntry);
            if (!validationResult.isSuccess) {
                throw new BDCException(String.join(validationResult.errors, '; '));
            }
            return this.getFinancialInstitutionsViaRouter(options);
        }

        global BDCServiceResult getFinancialInstitutionIdentities(BDCServiceOptions options){
            if (options == null ) {
                throw new BDCException(ERR_BDC_MISSING_OPTIONS);
            }
            ServiceResult validationResult = APIServiceContext.validateServiceContext(this.serviceEntry);
            if (!validationResult.isSuccess) {
                throw new BDCException(String.join(validationResult.errors, '; '));
            }
            return this.getFinancialInstitutionIdentitiesViaRouter(options);
        }

        global BDCServiceResult getAccounts(BDCServiceOptions options){
            if (options == null ) {
                throw new BDCException(ERR_BDC_MISSING_OPTIONS);
            }
            ServiceResult validationResult = APIServiceContext.validateServiceContext(this.serviceEntry);
            if (!validationResult.isSuccess) {
                throw new BDCException(String.join(validationResult.errors, '; '));
            }
            return this.getAccountsViaRouter(options);
        }

        global BDCServiceResult getAccountsByIdentityIds(BDCServiceOptions options){
            if (options == null ) {
                throw new BDCException(ERR_BDC_MISSING_OPTIONS);
            }
            ServiceResult validationResult = APIServiceContext.validateServiceContext(this.serviceEntry);
            if (!validationResult.isSuccess) {
                throw new BDCException(String.join(validationResult.errors, '; '));
            }
            return this.getAccountsByIdentityIdsViaRouter(options);
        }


        global BDCServiceResult getCategories(BDCServiceOptions options){
            if (options == null ) {
                throw new BDCException(ERR_BDC_MISSING_OPTIONS);
            }
            ServiceResult validationResult = APIServiceContext.validateServiceContext(this.serviceEntry);
            if (!validationResult.isSuccess) {
                throw new BDCException(String.join(validationResult.errors, '; '));
            }
            return this.getCategoriesMapViaRouter(options);
        }

    //PRIVATE METHODS *******************************************************************

        private BDCServiceResult deleteFinInstViaRouter(BDCServiceOptions options){

            BDCServiceResult result = new BDCServiceResult();
            getBDCRouterClass(options.bdcBinding.Name);
            try {
                //get HTTP responses from connecter API calls
                connectorResponses = router.getConnector().deleteFinancialInstitutionIdentity(options.bdcFinancialInstitutionIdentities[0]);
                result = router.getConverter().convertDeleteFinancialInstitutionIdentity(connectorResponses, options.bdcFinancialInstitutionIdentities[0]);
                if(result.isSuccess == true) {
                    List<String> financialInstitutionId = new List<String>();
                    financialInstitutionId.add(options.bdcFinancialInstitutionIdentities[0].id);
                    inActiveGlamRecords(financialInstitutionId);
                } 
            } catch(Exception error) {
                result = handleException(error);
            }
            return result;

        }
    
    
        private BDCServiceResult getTransactionsViaRouter(BDCServiceOptions options){
            BDCServiceResult serviceResult = new BDCServiceResult();

            getBDCRouterClass(options.bdcBinding.Name);

            try {
                getTransactionsValidation(options);
                //get HTTP responses from connecter API calls
                connectorResponses = router.getConnector().getTransactions(options);
                //convert HTTP responses from connectors via the appropriate converter class
                List<BDCTransaction> transactions = new List<BDCTransaction>();
                serviceResult = router.getConverter().convertTransactions(connectorResponses);
                
            } catch(Exception error) {
                serviceResult = handleException(error);
            }
            return serviceResult;
        }

        private List<BDCServiceResult> getAllTransactionsBulkViaRouters(){
            List<BDCServiceResult> serviceResults = new List<BDCServiceResult>();
            
            BDCService service = new BDCService();
            for(BDC_Binding__c binding:  service.getBDCBindings()){
                if(binding.Is_Active__c){
                    BDCServiceResult serviceResult = new BDCServiceResult();
                    try {
                        //start the bulk processing of gettign all transactions
                        getTransactionsBulkViaRouter(binding.Name);
                        //if processessing started successfully
                        serviceResult.isSuccess = true;
        
                    } catch(Exception error) {
                        serviceResult = handleException(error);
                    }

                    serviceResults.add(serviceResult);
                }
            }

            return serviceResults;
        }

        private static void getTransactionsBulkViaRouter(string bindingName){
            BDCRouterFactory routerFactory = new BDCRouterFactory();
            AbstractBDCRouter router = routerFactory.locate(bindingName);
            router.getTransacationBulkProcessor().getAllTransactions(bindingName);
        }

        private BDCServiceResult getFinancialInstitutionsViaRouter(BDCServiceOptions options){
            BDCServiceResult serviceResult = new BDCServiceResult() ;

            getBDCRouterClass(options.bdcBinding.Name);
            
            try {
                getFinancialInstitutionValidation(options);
                //get responses from appropriate connector
                connectorResponses = router.getConnector().getFinancialInstitutions(options.bdcFinancialInstitutionIdentities);
                //convert HTTP responses from connectors via the appropriate converter class
                List<BDCFinancialInstitution> financialInstitutions = new List<BDCFinancialInstitution>();
                serviceResult = router.getConverter().convertFinancialInstitutions(connectorResponses);
            } catch(Exception error) {
                serviceResult = handleException(error);
            }
        
            return serviceResult;
        }

        private BDCServiceResult getFinancialInstitutionIdentitiesViaRouter(BDCServiceOptions options){
            BDCServiceResult serviceResult = new BDCServiceResult() ;
            getBDCRouterClass(options.bdcBinding.Name);

            try {
                //get responses from appropriate connector
                connectorResponses = router.getConnector().getFinancialInstitutionIdentities();
                //convert HTTP responses from connectors via the appropriate converter class
                List<BDCFinancialInstitutionIdentity> financialInstitutionIdentities = new List<BDCFinancialInstitutionIdentity>();
                serviceResult = router.getConverter().convertFinancialInstitutionIdentities(connectorResponses);
            } catch(Exception error) {
                serviceResult = handleException(error);
            }
        
            return serviceResult;
        }

        private BDCServiceResult getAccountsViaRouter(BDCServiceOptions options){
            BDCServiceResult serviceResult = new BDCServiceResult() ;
            getBDCRouterClass(options.bdcBinding.Name);

            try {
                getAccountsValidation(options);
                //get HTTP responses from connecter API calls
                connectorResponses = router.getConnector().getAccounts(options.bdcAccountIds);
                //convert HTTP responses from connectors via the appropriate converter class
                serviceResult = router.getConverter().convertAccounts(connectorResponses);   
            } catch(Exception error) {
                serviceResult = handleException(error);
            }
        
            return serviceResult;
        }

        private BDCServiceResult getAccountsByIdentityIdsViaRouter(BDCServiceOptions options){
            BDCServiceResult serviceResult = new BDCServiceResult() ;
            getBDCRouterClass(options.bdcBinding.Name);

            try {
                getAccountsByIdentityIdsValidation(options);
                //get HTTP responses from connecter API calls
                connectorResponses = router.getConnector().getAccountsFromFinancialInstitutionIdentities(options.bdcFinancialInstitutionIdentities);
                //convert HTTP responses from connectors via the appropriate converter class
                serviceResult = router.getConverter().convertAccounts(connectorResponses);                
            } catch(Exception error) {
                serviceResult = handleException(error);
            }
        
            return serviceResult;
        }

        private BDCServiceResult getCategoriesMapViaRouter(BDCServiceOptions options){
            BDCServiceResult serviceResult = new BDCServiceResult() ;
            getBDCRouterClass(options.bdcBinding.Name);
            Map<String, BDCCategory> mCategories = new Map<String, BDCCategory>();

            try {
                //get HTTP responses from connecter API calls
                connectorResponses = router.getConnector().getCategories();
                //convert HTTP responses from connectors via the appropriate converter class
                serviceResult = router.getConverter().convertCategories(connectorResponses);
            } catch(Exception error) {
                serviceResult = handleException(error);
            }
        
            return serviceResult;
        }


        private BDCServiceResult handleException(Exception except){
            BDCServiceResult result = new BDCServiceResult() ;
            BDCServiceResult.BDCError error = new BDCServiceResult.BDCError();
            error.detail = except.getMessage();
            error.code = except.getMessage();
            result = new BDCServiceResult(NULL, false, new BDCServiceResult.BDCError[]{error});
            return result;
        }

        private void getBDCRouterClass(String bindingName){
                router = this.routerFactory.locate(bindingName);
                if (router == null ) {
                    throw new BDCException(ERR_BDC_MISSING_ROUTER);
                } 
        }

    /**
    * This method is used used for make Glam records inactive corrsopond to inactive binding records after successfully  the providers
    */
    private static void inActiveGlamRecords(List<String> financialInstitutionIdentities){
        List<GL_Account_Mapping__c> BDCData = new List<GL_Account_Mapping__c>();
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
        List<String> queryFields = new List<String> {
            'Id',
                'Inactive__c',
                'Financial_Institution_Id__c'
                };
                    
                    SOQLBuilder theQuery = new SOQLBuilder(GL_Account_Mapping__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition('Inactive__c = FALSE AND Financial_Institution_Id__c IN: financialInstitutionIdentities')
            .setLimit(50000);
        
           
        for(GL_Account_Mapping__c glam : (List<GL_Account_Mapping__c>)Database.query(theQuery.toSOQL())){
            glam.Inactive__c = true;
            BDCData.add(glam);
        }

       
        SFDCSecurityUtils.updateProxy(BDCData);
        GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;
    }

    //VALIDATIONS *******************************************************************
    private void getTransactionsValidation(BDCServiceOptions options){
        validateFromDate(options.fromDate);
        validateToDate(options.toDate);
        validateDateRange(options.fromDate, options.toDate);
        validateAccountIDs(options.bdcAccountIds);
    }

    private void getTransactionsBulkValidation(BDCServiceOptions options){
        validateFromDate(options.fromDate);
        validateToDate(options.toDate);
        validateDateRange(options.fromDate, options.toDate);
    }

    private void getFinancialInstitutionValidation(BDCServiceOptions options){
        validateFinancialInstitutionIdentities(options.bdcFinancialInstitutionIdentities);
    }

    private void getAccountsValidation(BDCServiceOptions options){
        validateAccountIDs(options.bdcAccountIds);
    }

    private void getAccountsByIdentityIdsValidation(BDCServiceOptions options){
        validateFinancialInstitutionIdentities(options.bdcFinancialInstitutionIdentities);
    }

    private void validateFromDate(Date fromDate) {
        if (fromDate == null) {
            throw new BDCException(ERR_BDC_MISSING_FROM_DATE);
        }
    }

    private void validateToDate(Date toDate) {
        if (toDate == null) {
            throw new BDCException(ERR_BDC_MISSING_TO_DATE);
        }
    }

    private void validateDateRange(Date fromDate, Date toDate){
        if(toDate < fromDate){
            throw new BDCException(ERR_BDC_INVALID_DATE_RANGE);
        }
    }

    private void validateAccountIDs(List<String> bdcAccountIds) {
        if (bdcAccountIds == null || bdcAccountIds.size() <= 0) {
            throw new BDCException(ERR_BDC_MISSING_ACCOUNT_IDS);
        }
    }

    private void validateFIAs(List<String> bdcFinancialInstitutionIds) {
        if (bdcFinancialInstitutionIds == null || bdcFinancialInstitutionIds.size() <= 0) {
            throw new BDCException(ERR_BDC_MISSING_FI_IDS);
        }
    }

    private void validateFinancialInstitutionIdentities(List<BDCFinancialInstitutionIdentity> bdcFinancialInstitutionIdentities){
        if (bdcFinancialInstitutionIdentities == null || bdcFinancialInstitutionIdentities.size() <= 0) {
            throw new BDCException(ERR_BDC_MISSING_FI_IDENTITY_IDS);
        }
    }

}
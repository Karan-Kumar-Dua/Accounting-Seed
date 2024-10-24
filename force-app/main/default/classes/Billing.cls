public with sharing class Billing {

    public static final String NO_INPUT_DATA = Label.ERR_NO_INPUT_DATA;
    @TestVisible
    private static final String INVALID_RECORD_OR_ID = Label.ERR_INVALID_RECORD_OR_ID;

    @TestVisible
    private APIServiceContext.APIServiceEntry serviceEntry;
    private List<BillingModel> billModels;
    private List<CashApplication> cashApplications;
    private List<Id> billIds;
    private ServiceResult serviceResult;

    public enum StatusCode {NO_INPUT_DATA, INVALID_RECORD_OR_ID, NO_BILLING_FORMAT_ERROR, NO_VF_PAGE_ERROR}

    public class BillingException extends Exception {}

    //========================================================================================
    //================= CLASS CONSTRUCTORS ===================+===============================
    //========================================================================================

    public Billing() {
        this.serviceEntry = new APIServiceContext.APIServiceEntry();
        this.billModels = new List<BillingModel>();
        this.cashApplications = new List<CashApplication>();
    }

    public Billing(List<BillingModel> models) {
        this();
        this.billModels = models;
        if (this.billModels.isEmpty()) {
            throw new BillingException(NO_INPUT_DATA);
        }
    }

    public Billing(BillingModel model) {
        this();
        if (model != NULL) {
            this.billModels = new List<BillingModel>{model};
        }
        if (this.billModels.isEmpty()) {
            throw new BillingException(NO_INPUT_DATA);
        }
    }

    public Billing(List<Id> billingIds) {
        this();
        this.billIds = billingIds;
    }

    public Billing(Id billingId) {
        this(new List<Id>{billingId});
    }

    public void setServiceEntry(APIServiceContext.APIServiceEntry value) {
        this.serviceEntry = value;
    }

    public APIServiceContext.APIServiceEntry getServiceEntry() {
        return this.serviceEntry;
    }

    //========================================================================================
    //================= GLOBAL ENTRY POINTS ==================================================
    //========================================================================================
    public static ServiceResult create(BillingModel model) {
        ServiceResult sr;
        try {
            Billing billServiceController = new Billing(model);
            sr = APIServiceContext.validateServiceContext(billServiceController.serviceEntry);

            if (sr.isSuccess) {
                sr = billServiceController.create();
            }
        }
        catch (Exception ex) {
            sr = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }

        return sr;
    }

    public static ServiceResult create(List<BillingModel> models) {
        ServiceResult sr;
        try {
            Billing billServiceController = new Billing(models);
            sr = APIServiceContext.validateServiceContext(billServiceController.serviceEntry);

            if (sr.isSuccess) {
                sr = billServiceController.create();
            }
        }
        catch (Exception ex) {
            sr = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return sr;
    }

    public static ServiceResult post(Id billingId) {
        ServiceResult sr;
        try {
            Billing billServiceController = new Billing(billingId);
            sr = APIServiceContext.validateServiceContext(billServiceController.serviceEntry);

            if (sr.isSuccess) {
                List<ServiceResult> postServiceResults = billServiceController.post();
                sr = (!postServiceResults.isEmpty()) ? postServiceResults.get(0) : new ServiceResult(billingId, false);
            }
        }
        catch (Exception ex) {
            sr = new ServiceResult(billingId, false, new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())});
        }

        return sr;
    }

    public static List<ServiceResult> post(List<Id> billingIds) {
        List<ServiceResult> postServiceResults;
        try {
            Billing billServiceController = new Billing(billingIds);
            ServiceResult sr = APIServiceContext.validateServiceContext(billServiceController.serviceEntry);

            if (sr.isSuccess) {
                postServiceResults = billServiceController.post();
            }
        }
        catch (Exception ex) {
            postServiceResults = new List<ServiceResult>();
            for (Id billingId : billingIds) {
                postServiceResults.add(
                    new ServiceResult(
                        billingId,
                        false,
                        new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())}
                    )
                );
            }
        }
        return postServiceResults;
    }

    public static ServiceResult unpost(Id billingId) {
        ServiceResult sr;
        try {
            Billing billServiceController = new Billing(billingId);
            sr = APIServiceContext.validateServiceContext(billServiceController.serviceEntry);

            if (sr.isSuccess) {
                List<ServiceResult> postServiceResults = billServiceController.unpost();
                sr = (!postServiceResults.isEmpty()) ? postServiceResults.get(0) : new ServiceResult(billingId, false);
            }
        }
        catch (Exception ex) {
            sr = new ServiceResult(billingId, false, new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())});
        }

        return sr;
    }

    public static List<ServiceResult> unpost(List<Id> billingIds) {
        List<ServiceResult> unpostServiceResults;
        try {
            Billing billServiceController = new Billing(billingIds);
            ServiceResult sr = APIServiceContext.validateServiceContext(billServiceController.serviceEntry);

            if (sr.isSuccess) {
                unpostServiceResults = billServiceController.unpost();
            }
        }
        catch (Exception ex) {
            unpostServiceResults = new List<ServiceResult>();
            for (Id billingId : billingIds) {
                unpostServiceResults.add(
                    new ServiceResult(
                        billingId,
                        false,
                        new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())}
                    )
                );
            }
        }

        return unpostServiceResults;
    }

    public static BillingModel calcTax(Id billingId) {
        BillingModel result;
        try {
            Billing billServiceController = new Billing(billingId);
            APIServiceContext.APIServiceEntry serviceEntry = billServiceController.getServiceEntry();
            serviceEntry.isOnlyAvaTaxContextAccessible = true;
            serviceEntry.isAvaTaxContext = AvaTaxHelper.isAvalaraTaxCalculationEnabled(Billing.retrieve(billingId).bill);
            billServiceController.setServiceEntry(serviceEntry);
            ServiceResult sr = APIServiceContext.validateServiceContext(billServiceController.serviceEntry);

            if (sr.isSuccess) {
                result = billServiceController.calcTaxImpl(billingId);
            }
            else {
                throw new BillingException(sr.errors.get(0).detail);
            }
        }
        catch (Exception ex) {
            throw new BillingException(ex.getMessage());
        }

        return result;
    }
    
    public static BillingModel retrieve(Id billingId) {
        return Billing.retrieve(billingId, false, null);
    }

    public static BillingModel retrieve(Id billingId, Boolean forClone) {
        return Billing.retrieve(billingId, false, null);
    }

    public static BillingModel retrieve(Id billingId, boolean forClone, Set<String> includeBillingLineFields) {
        BillingModel bm;
        try {
            Billing billServiceController = new Billing(billingId);
            ServiceResult sr = APIServiceContext.validateServiceContext(billServiceController.serviceEntry);
            if (sr.isSuccess) {
                bm = billServiceController.retrieveImpl(forClone, includeBillingLineFields);
            }
        }
        catch (Exception ex) {
            bm = new BillingModel();
        }

        return bm;
    }

    public static Blob generatePDF(Id billingId) {
        Blob pdf;
        try {
            Billing billServiceController = new Billing(billingId);
            ServiceResult sr = APIServiceContext.validateServiceContext(billServiceController.serviceEntry);
            if (sr.isSuccess) {
                pdf = billServiceController.generatePDFImpl();
            }
        }
        catch (Exception ex) {
            throw new BillingException(ex.getMessage());
        }
        return pdf;
    }

    //========================================================================================
    //================= IMPLEMENTATION INSTANCE METHODS ======================================
    //========================================================================================

    private BillingModel calcTaxImpl(Id billingId) {
        BillingModel result = new BillingModel();
        if (billingId != NULL && FinancialSuiteUtils.isValidId(billingId, Billing__c.SObjectType)) {
            AvaTaxHelper.AvaTaxCalculationResult avaTaxCalculationResult = AvaTaxHelper.calcTaxAPI(billingId);
            if (avaTaxCalculationResult.reportMap.get(billingId).isSuccess) {
                result = retrieveImpl(false, null);
            }
            else {
                throw new BillingException(avaTaxCalculationResult.reportMap.get(billingId).error.errorMsg);
            }
        }
        else {
            throw new BillingException(Billing.INVALID_RECORD_OR_ID);
        }
        return result;
    }

    private ServiceResult create() {
        List<ServiceResult> billingServiceResults = new List<ServiceResult>();
        Savepoint sp = Database.setSavepoint();
        try {
            if (!this.billModels.isEmpty()) {
                //insert Billings first
                List<Billing__c> billingsToInsert = new List<Billing__c>();
                for (BillingModel billModel : this.billModels) {
                    ServiceResult sr = validateBillingModel(billModel);
                    if (sr.isSuccess) {
                        billingsToInsert.add(billModel.bill);
                    }
                    else {
                        billingServiceResults.add(sr);
                    }
                }

                for (Database.SaveResult saveResult : SFDCSecurityUtils.insertCheckCRUDAndFLS(billingsToInsert, getFieldsToCheckFLS(billingsToInsert), false)) {
                    if (saveResult.isSuccess()) {
                        billingServiceResults.add(new ServiceResult(saveResult.getId(), true));
                    }
                    else {
                        List<ServiceResult.Error> errors = new List<ServiceResult.Error>();
                        for (Database.Error dbError : saveResult.getErrors()) {
                            ServiceResult.Error err = new ServiceResult.Error(dbError.getStatusCode().name(), dbError.getMessage());
                            errors.add(err);
                        }
                        billingServiceResults.add(new ServiceResult(NULL, false, errors));
                    }
                }
                //populate Billing Id on related Billing Lines and save them
                List<Billing_Line__c> linesToInsert = new List<Billing_Line__c>();
                for (BillingModel billModel : this.billModels) {
                    if (isSavedInDataBase(billModel.bill) && isNotNullAndNotEmpty(billModel.billLines)) {
                        for (Billing_Line__c line : billModel.billLines) {
                            line.Billing__c = billModel.bill.Id;
                            linesToInsert.add(line);
                        }
                    }
                }
                //save Billing Lines
                List<Database.SaveResult> saveResults = SFDCSecurityUtils.insertCheckCRUDAndFLS(linesToInsert, getFieldsToCheckFLS(linesToInsert), false);
                //Handle Billing Line save results
                for (Integer i = 0; i < linesToInsert.size(); i++) {
                    Database.SaveResult sResult = saveResults.get(i);
                    Id billingId = linesToInsert.get(i).Billing__c;
                    //Update Billing Level ServiceResults
                    for (ServiceResult billingServiceResult : billingServiceResults) {
                        if (billingServiceResult.data == billingId) {
                            ServiceResult lineServiceResult;
                            if (!sResult.isSuccess()) {
                                //If line has not been saved - create ServiceResult with error for the line
                                //And put it in Billing level Service Result
                                List<ServiceResult.Error> errors = new List<ServiceResult.Error>();
                                for (Database.Error dbError : sResult.getErrors()) {
                                    ServiceResult.Error err = new ServiceResult.Error(dbError.getStatusCode().name(), dbError.getMessage());
                                    errors.add(err);
                                }
                                lineServiceResult = new ServiceResult(NULL, false, errors);
                            }
                            else {
                                //If line has been saved successfully - create success ServiceResult for the line
                                //And put it in Billing level Service Result
                                lineServiceResult = new ServiceResult(sResult.getId(), true);
                            }
                            billingServiceResult.results.add(lineServiceResult);
                        }
                    }
                }
                //Combine all results into one common ServiceResult
                if (billingServiceResults.size() == 1) {
                    this.serviceResult = billingServiceResults[0];
                }
                else if (billingServiceResults.size() > 1) {
                    this.serviceResult = new ServiceResult(NULL, true, NULL, billingServiceResults);
                }
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            this.serviceResult = new ServiceResult(NULL, false, new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())});
        }
        return this.serviceResult;
    }

    private List<ServiceResult> post() {
        AbstractPostHandler postHandler = new BillingPostHandler();
        List<PostResult> postResults = postHandler.post(this.billIds);
        return transformPostResults(postResults);
    }

    private List<ServiceResult> unpost() {
        AbstractPostHandler postHandler = new BillingPostHandler();
        List<PostResult> postResults = postHandler.unpost(this.billIds);
        return transformPostResults(postResults);
    }

    private BillingModel retrieveImpl(boolean forClone, Set<String> includeBillingLineFields) {
        this.billModels.add(new BillingModel());
        try {
            if (!this.billIds.isEmpty() && FinancialSuiteUtils.isValidId(this.billIds[0], Billing__c.SObjectType)) {
                this.billModels[0].billLines = new List<Billing_Line__c>();
                for (Billing__c bill : queryBillingsWithLinesToRetrieve(new Set<Id>{this.billIds[0]}, forClone, includeBillingLineFields)) {
                    this.billModels[0].bill = bill;
                    this.billModels[0].billLines = new List<Billing_Line__c>();
                    for (Billing_Line__c line : bill.Project_Billing_Lines__r) {
                        this.billModels[0].billLines.add(line);
                    }
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return this.billModels[0];
    }

    private List<Billing__c> queryBillingsWithLinesToRetrieve(Set<Id> billingIds, boolean forClone, Set<String> includeBillingLineFields) {
        //Get list of accessible fields on Billing
        List<String> queryFields = new List<String>();
        //Get list of accessible fields on Billing Line
        Set<String> subQueryFields = new Set<String>();

        if(!forClone){
            queryFields.addAll(SFDCSecurityUtils.getOnlyAccessibleFields(Billing__c.SObjectType));
            subQueryFields.addAll(SFDCSecurityUtils.getOnlyAccessibleFields(Billing_Line__c.SObjectType));
            if (includeBillingLineFields != null) {
                subQueryFields.addAll(includeBillingLineFields);
            }
        }
        else {
            queryFields.addAll(SFDCSecurityUtils.getUpdateableCreatableFields(Billing__c.SObjectType));
            subQueryFields.addAll(SFDCSecurityUtils.getUpdateableCreatableFields(Billing_Line__c.SObjectType));
            if (includeBillingLineFields != null) {
                subQueryFields.addAll(includeBillingLineFields);
            }
        }
        
       // subQueryFields.addAll(SFDCSecurityUtils.getOnlyAccessibleFields(Billing_Line__c.SObjectType));
        String queryCondition = 'Id IN :billingIds';
        String subQueryRelationshipName = GlobalVariables.PACKAGE_QUALIFIER + 'Project_Billing_Lines__r';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(subQueryRelationshipName, true)
            .setEnforceFLS(true)
            .selectFields(new List<String>(subQueryFields));

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }

    private Blob generatePDFImpl() {
        Blob pdf;
        try {
            if (!this.billIds.isEmpty() && FinancialSuiteUtils.isValidId(this.billIds[0], Billing__c.SObjectType)) {
                List<Billing__c> billings = queryBillingsForPdfGeneration(new Set<Id>{this.billIds[0]});
                this.serviceResult = validateBillingForPdfGeneration(billings.get(0));
                if (this.serviceResult.isSuccess) {
                    pdf = processPdfGeneration(billings).get(0);
                }
                else {
                    throw new BillingException(this.serviceResult.errors.get(0).detail);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return pdf;
    }

    public List<Billing__c> queryBillingsForPdfGeneration(Set<Id> billingIds) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Customer__c',
            'Customer__r.Name',
            'Billing_Contact__c',
            'Billing_Contact__r.FirstName',
            'Billing_Contact__r.LastName',
            'Billing_Contact__r.Email',
            'Billing_Format__c',
            'Billing_Format__r.Default_Email_Template__c',
            'Billing_Format__r.ReplyTo_Email__c',
            'Billing_Format__r.Visualforce_PDF_Page__c',
            'Billing_Format__r.Sort_Field__c',
            'Billing_Format__r.Org_Wide_Email_Address__c',
            'Proprietary_Billing_Number__c',
            'Status__c',
            'Date__c',
            'PDF_Email_Status__c'
        };

        String queryCondition = 'Id IN :billingIds';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }

    //======================================================================================
    //======================= UTILITY METHODS ==============================================
    //======================================================================================
    private Boolean isNotNullAndNotEmpty(List<SObject> collection) {
        return collection != NULL && !collection.isEmpty();
    }

    private Boolean isSavedInDataBase(SObject record) {
        return record != NULL && record.Id != NULL;
    }

    private ServiceResult validateBillingModel(BillingModel model) {
        ServiceResult sr = new ServiceResult(NULL, true);
        ServiceResult.Error error = new ServiceResult.Error();
        if (model.bill == NULL) {
            error.detail = INVALID_RECORD_OR_ID;
            error.code = StatusCode.INVALID_RECORD_OR_ID.name();
        }
        if (error.detail != NULL) {
            sr = new ServiceResult(NULL, false, new List<ServiceResult.Error>{error});
        }
        return sr;
    }

    private List<Blob> processPdfGeneration(List<Billing__c> billings) {
        List<Blob> pdfDocs = new List<Blob>();
        try {
            String pageUrl = '';
            AbstractStatementManager.StatementSet statementManager = new AbstractStatementManager.StatementSet(
                billings, AbstractStatementManager.StatementType.BILLING, pageUrl
            );
            for (AbstractStatementManager.Statement eachStatement : statementManager.statements) {
                pdfDocs.add(eachStatement.getPDF());
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return pdfDocs;
    }

    private ServiceResult validateBillingForPdfGeneration(Billing__c billing) {
        ServiceResult sr = new ServiceResult(NULL, true);
        ServiceResult.Error error = new ServiceResult.Error();
        if (billing.Billing_Format__r == NULL) {
            error.detail = BillingPDFManager.NO_BILLING_FORMAT_ERROR;
            error.code = StatusCode.NO_BILLING_FORMAT_ERROR.name();
        }
        else if (billing.Billing_Format__r.Visualforce_PDF_Page__c == NULL) {
            error.detail = BillingPDFManager.NO_VF_PAGE_ERROR;
            error.code = StatusCode.NO_VF_PAGE_ERROR.name();
        }

        if (error.detail != NULL) {
            sr = new ServiceResult(NULL, false, new List<ServiceResult.Error>{error});
        }

        return sr;
    }

    private List<String> getFieldsToCheckFLS(List<SObject> records) {
        List<String> result = new List<String>();
        if (records != NULL && !records.isEmpty()) {
            Set<String> fields = new Set<String>();
            for (SObject record : records) {
                for(string fieldAPI :record.getPopulatedFieldsAsMap().keySet() ){
                    if(!fieldAPI.endsWith('__r')){
                        fields.add(fieldAPI);
                    }           
                }
            }
            result.addAll(fields);
        }
        return result;
    }

    private List<ServiceResult> transformPostResults(List<PostResult> postResults) {
        List<ServiceResult> results = new List<ServiceResult>();
        for (PostResult pr : postResults) {
            results.add(transformPostResult(pr));
        }
        return results;
    }

    private ServiceResult transformPostResult(PostResult pr) {
        ServiceResult sr = new ServiceResult();
        sr.isSuccess = pr.isSuccess;
        sr.data = pr.id;
        if (pr.errors != NULL) {
            sr.errors = transformPostErrorResults(pr.errors);
        }
        return sr;
    }

    private List<ServiceResult.Error> transformPostErrorResults(List<PostResult.PostErrorResult> postErrResults) {
        List<ServiceResult.Error> srErrors = new List<ServiceResult.Error>();
        for (PostResult.PostErrorResult postErrResult : postErrResults) {
            srErrors.add(transformPostErrorResult(postErrResult));
        }
        return srErrors;
    }

    private ServiceResult.Error transformPostErrorResult(PostResult.PostErrorResult postErrResult) {
        ServiceResult.Error srError = new ServiceResult.Error();
        srError.id = (postErrResult.errorSource != NULL) ? postErrResult.errorSource.Id : NULL;
        srError.code = postErrResult.statusCode.name();
        srError.detail = postErrResult.message;
        return srError;
    }

}
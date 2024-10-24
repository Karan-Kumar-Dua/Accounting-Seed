public with sharing class ImportFileWizardHelper extends AbstractLWCHelper {

    @TestVisible
    private static final String FILE_VERIFICATION_SUCCESS_MESSAGE = Label.INF_FILE_VERIFICATION_SUCCESS_MESSAGE;
    private static final String FILE_VERIFICATION_NO_FINANCIAL_DATA_ERROR_MESSAGE = Label.ERR_FILE_VERIFICATION_NO_FINANCIAL_DATA;
    @TestVisible
    private static final String FILE_VERIFICATION_NO_TRANSACTION_DATA_ERROR_MESSAGE = LAbel.ERR_FILE_VERIFICATION_NO_TRANSACTION_DATA;
    private static final String FILE_IMPORT_COMPLETE_MESSAGE = Label.INF_FILE_IMPORT_COMPLETE_MESSAGE;
    private static final String FILE_IMPORT_BACKGROUND_JOB_STARTED_MESSAGE = Label.INF_FILE_IMPORT_BACKGROUND_JOB_STARTED_MESSAGE;
    private static final Integer MAX_TRANS_COUNT = 500;
    @TestVisible
    private static final String MAX_TRANS_COUNT_ERROR_MESSAGE = String.format(Label.ERR_MAX_TRANS_COUNT, new List<Object>{ MAX_TRANS_COUNT }) + ' ' + MAX_TRANS_COUNT + '.';
    private static final String EXPECTED_STRING_ERROR = 'STRING_TOO_LONG';
    private static final String EXPECTED_STRING_ERROR_FIELD = GlobalVariables.PACKAGE_QUALIFIER + 'Account_Id__c';
    public static final Integer TRANSACTIONS_PAGE_SIZE = 50;

    @AuraEnabled
    public static ImportFileDTO parseFile(Id contentDocumentId) {
        ImportFileDTO result;
        try {
            if (contentDocumentId != NULL) {
                List<ContentVersion> uploadedFiles = DomainUtils.getFilesByContentDocumentId(new Set<Id>{contentDocumentId});
                if (!uploadedFiles.isEmpty() && uploadedFiles[0].VersionData != NULL) {
                    OFXFileParser ofxParser = new OFXFileParser(uploadedFiles[0].VersionData.toString());
                    if (ofxParser.isValidFileFormat()) {
                        ofxParser.parseToTransactionModels();
                        if (ofxParser.getTransactionCount() > 0) {
                            if (ofxParser.getTransactionCount() <= MAX_TRANS_COUNT) {
                                String fid = ofxParser.financialInstitutionId;
                                String fiName = ofxParser.financialInstitutionName;
                                String accountId = ofxParser.accountId;
                                List<GL_Account_Mapping__c> glams = new List<GL_Account_Mapping__c>();
                                if (!String.isBlank(accountId)) {
                                    glams = DomainUtils.getGLAccountMappingsByExternalIds(new Set<String>{
                                        accountId
                                    });
                                }
                                result = new ImportFileDTO(
                                    fid,
                                    fiName,
                                    accountId,
                                    (glams.isEmpty() ? NULL : glams[0]),
                                    ofxParser.transactionModels,
                                    ofxParser.transCurrency
                                );
                            }
                            else {
                                result = new ImportFileDTO(MAX_TRANS_COUNT_ERROR_MESSAGE);
                            }
                        }
                        else {
                            result = new ImportFileDTO(FILE_VERIFICATION_NO_TRANSACTION_DATA_ERROR_MESSAGE);
                        }
                    }
                    else {
                        result = new ImportFileDTO(OFXFileParser.FILE_FORMAT_ERROR);
                    }
                }
                else {
                    result = new ImportFileDTO(FILE_VERIFICATION_NO_FINANCIAL_DATA_ERROR_MESSAGE);
                }
            }
        }
        catch (StringException ex) {
            result = new ImportFileDTO(OFXFileParser.FILE_FORMAT_ERROR);
        }
        catch (Exception ex) {
            result = new ImportFileDTO(ex.getMessage());
        }
        finally {
            deleteFile(contentDocumentId);
        }

        return result;
    }

    private static void deleteFile(Id contentDocumentId) {
        if (contentDocumentId != NULL) {
            try {
                SFDCSecurityUtils.deleteProxy(DomainUtils.getContentDocumentsById(new Set<Id>{contentDocumentId}));
            }
            catch (Exception ex) {

            }
        }
    }

    @AuraEnabled
    public static String importBankTransactions(String serializedImportFileDto, Id glAccountId, Id ledgerId) {
        if (String.isNotBlank(ledgerId) && !LedgerHandler.getInstanceWithoutSharing().isActiveLedger(ledgerId)) {
            ledgerId = LedgerHandler.getLedgerIdWithSharing();
            if (String.isNotBlank(ledgerId) && !LedgerHandler.getInstanceWithoutSharing().isActiveLedger(ledgerId)) {
                throw buildException(ExceptionCode.UNKNOWN, Label.ERR_LEDGER_ACTIVE_ONLY);
            }
        }

        try {
            ImportFileDto dto = (ImportFileDto) JSON.deserialize(serializedImportFileDto, ImportFileDto.class);
            dto.glam.glAccountId = glAccountId;
            dto.glam.ledgerId = ledgerId;
            //Upsert GLAM
            GL_Account_Mapping__c glam = new GL_Account_Mapping__c(
                Id = dto.glam.glamId,
                Ledger__c = dto.glam.ledgerId,
                GL_Account__c = dto.glam.glAccountId,
                External_Id__c = dto.accountId,
                Account_Name__c = dto.accountId,
                Financial_Institution_Id__c = dto.financialInstitutionId,
                Financial_Institution__c = dto.financialInstitutionName,
                Source__c = BankTransactionsHelper.SOURCE_FINANCIAL_FILE_IMPORT
            );
            if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
                glam.put('CurrencyIsoCode', dto.currencyIsoCode);
            }
            GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
            SFDCSecurityUtils.upsertProxy(glam);
            GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;

            List<BDCTransaction> transactionModels =
                (List<BDCTransaction>) JSON.deserialize(
                    dto.serializedTransactionModels, List<BDCTransaction>.class
                );

            //Insert BTs
            List<Bank_Transaction__c> bankTransactions = BankTransactionsHelper.createBankTransactions(transactionModels, NULL, BankTransactionsHelper.SOURCE_FINANCIAL_FILE_IMPORT);

            BankTransactionsHelper.processAutomatedMatchAndAddAsync(bankTransactions);
            return FILE_IMPORT_BACKGROUND_JOB_STARTED_MESSAGE;
        }catch(DmlException e){
            String error = e.getDmlMessage(0);
            if(e.getDmlFieldNames(0)[0] == EXPECTED_STRING_ERROR_FIELD && error.contains(EXPECTED_STRING_ERROR)){
                error = Label.ERR_ACCOUNT_ID_CANNOT_BE_MORE_THAN_50_CHARACTERS;
            }
            throw buildException(ExceptionCode.UNKNOWN, error);
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static GL_Account_Mapping__c getGLAMDefaults() {
        GL_Account_Mapping__c defaults;
        try {    
            defaults = new GL_Account_Mapping__c(
                Ledger__c = LedgerHandler.getLedgerIdWithSharing()
            );
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return defaults;
    }

    public class ImportFileCustomException extends Exception {}

    public class ImportFileDTO {
        @AuraEnabled
        public String financialInstitutionId;
        @AuraEnabled
        public String financialInstitutionName;
        @AuraEnabled
        public String accountId;
        @AuraEnabled
        public GlamModel glam;
        @AuraEnabled
        public String serializedTransactionModels;
        @AuraEnabled
        public Boolean isValid;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public String currencyIsoCode;

        public ImportFileDTO(
            String fid,
            String fiName,
            String accountId,
            GL_Account_Mapping__c glam,
            List<BDCTransaction> transactionModels,
            String currencyIsoCode
        ) {

            this.isValid = true;
            this.message = FILE_VERIFICATION_SUCCESS_MESSAGE;
            this.financialInstitutionId = fid;
            this.financialInstitutionName = fiName;
            this.accountId = accountId;
            this.glam = new GlamModel(glam);
            this.currencyIsoCode = currencyIsoCode;
            this.serializedTransactionModels = JSON.serialize(transactionModels);
        }

        public ImportFileDTO(String errorMessage) {
            this.isValid = false;
            this.message = errorMessage;
        }
    }

    public class GlamModel {
        @AuraEnabled
        public String glamId;
        @AuraEnabled
        public String ledgerId;
        @AuraEnabled
        public String glAccountId;

        public GlamModel(GL_Account_Mapping__c glam) {
            if (glam != NULL) {
                this.glamId = glam.Id;
                this.ledgerId = glam.Ledger__c;
                this.glAccountId = glam.GL_Account__c;
            }
        }
    }

}
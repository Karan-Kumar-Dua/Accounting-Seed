public with sharing class BankReconciliationHelper extends AbstractLWCHelper {

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    private static final string PDF_FILE_NAME = Label.PDF_FILE_NAME;

    @AuraEnabled
    public static Bank_Reconciliation2__c getBankRec(Id bankRecId) {
        Bank_Reconciliation2__c bankRec;
        try {
            List<Bank_Reconciliation2__c> bankRecList = DomainUtils.getBankRecsById(new Set<Id> {bankRecId});
            if (!bankRecList.isEmpty()) {
                bankRec = bankRecList[0];
            }
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return bankRec;
    }

    @AuraEnabled(cacheable=true)
    public static BankRecMCWrapper isMultiCurrencyEnabled(Id bankRecId){
        BankRecMCWrapper result = new BankRecMCWrapper();
        List<Bank_Reconciliation2__c> bankRecList = DomainUtils.getBankRecsById(new Set<Id> {bankRecId});
        if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED && !bankRecList.isEmpty()) {
            result.currencyIsoCode = (String) bankRecList[0].get('CurrencyIsoCode');
            if (((String) bankRecList[0].get('CurrencyIsoCode') == (String) bankRecList[0].getSObject('Ledger__r').get('CurrencyIsoCode'))) {
                result.isSameCurrencyAsLedger = true;
            }
        }

        return result;
    }

    public with sharing class BankRecMCWrapper {
        @AuraEnabled
        public String currencyIsoCode = UserInfo.getDefaultCurrency();
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled = AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED;
        @AuraEnabled
        public Boolean isSameCurrencyAsLedger = false;
    }

    @AuraEnabled
    public static SaveResponse setClearedDate(Id sourceRecordId, Date clearedDateValue) {
        SaveResponse result = new SaveResponse();
        try {
            SObject sourceObj = sourceRecordId.getSobjectType().newSObject(sourceRecordId);
            sourceObj.put(PACKAGE_QUALIFIER + 'Cleared_Date__c', clearedDateValue);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceObj, new List<String>{'Cleared_Date__c'});
            result.isSuccess = true;
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_WRITE, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static SaveResponse clearItems(Id bankRecId, List<Id> sourceRecIds) {
        SaveResponse result = new SaveResponse();
        try {
            result = new SaveResponse(BankReconciliation.clear(bankRecId, sourceRecIds));
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static SaveResponse unclearItems(Id bankRecId, List<Id> sourceRecIds) {
        SaveResponse result = new SaveResponse();
        try {
            result = new SaveResponse(BankReconciliation.unclear(bankRecId, sourceRecIds));
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static SaveResponse setCompleted(String bankRecId) {
        SaveResponse result = new SaveResponse();
        try {
            result = new SaveResponse(BankReconciliation.complete(bankRecId));
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_WRITE, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static SaveResponse runAutoClearJob(String bankRecId) {
        return handleRunAutoClearJob(bankRecId);
    }

    @AuraEnabled
    public static SaveResponse setInProgress(String bankRecId) {
        SaveResponse result = new SaveResponse();
        try {
            result = new SaveResponse(BankReconciliation.undoComplete(bankRecId));
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_WRITE, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static List<Sobject> getAllRecords(Id bankRecId) {
        List<Sobject> result = new List<Sobject>();
        try {
            result = BankReconciliation.retrieve(bankRecId, true, true).items;
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Integer getRecordCount(Id bankRecId) {
        Integer recordCount;
        try {
            BankReconciliationModel model = BankReconciliation.retrieveItemCount(bankRecId);
            recordCount = model.recordCount;
        } 
        catch (AuraHandledException ex) {
            throw ex;
        } 
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return recordCount;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Bank_Reconciliation2__c> getPrevNextLastBankRecs(Id bankRecId) {
        Map<String, Bank_Reconciliation2__c> result = new Map<String, Bank_Reconciliation2__c>();
        try {
            Bank_Reconciliation2__c bankRec = DomainUtils.getBankReconciliationById(bankRecId);
            List<Bank_Reconciliation2__c>  bankRecsList = DomainUtils.getRelatedBankRecs(bankRec, false, true, true);
            if(bankRecsList != null && !bankRecsList.isEmpty()){
                Bank_Reconciliation2__c previousBankRec = null;
                Bank_Reconciliation2__c nextBankRec = null;
                for (Bank_Reconciliation2__c bankReconciliation : bankRecsList) {
                    if (bankReconciliation.Id == bankRec.Id) {
                        previousBankRec = bankReconciliation;
                        break;
                    }
                    nextBankRec = bankReconciliation;
                }
                result = new Map<String, Bank_Reconciliation2__c>{
                        'lastBankRec' => bankRecsList[0],
                        'previousBankRec' => previousBankRec,
                        'nextBankRec' => nextBankRec
                };
            }

        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }

        return result;
    }

    @AuraEnabled
    public static void createBankReconciliationPDFReport(Id bankRecId) {
        createBankReconciliationPDFReportFuture(bankRecId);
    }

    @Future(callout=true)
    public static void createBankReconciliationPDFReportFuture(Id bankRecId) {
        Bank_Reconciliation2__c bankRec = DomainUtils.getBankReconciliationById(bankRecId);
        PageReference clearedPdf = Page.BankReconciliationPDFReportNew;
        clearedPdf.getParameters().put('id', bankRecId);
        Blob clearedBody = Test.isRunningTest() ? Blob.valueOf('test') : clearedPdf.getContent();
        String clearedName = String.format(
            PDF_FILE_NAME, 
            new String[]{bankRec.Bank_Account__r.Name, bankRec.End_Date__c.format(), System.now().format()}
        );
        saveContentVersion(clearedName, clearedBody, bankRecId);
    }

    @AuraEnabled
    public static void createBankReconciliationCSVFile(Id bankRecId) {
        Database.executeBatch(new BankReconciliationCSVGeneratorBatch(bankRecId), 1000);
    }

    public static void saveContentVersion(String fileName, Blob fileBody, Id bankRecId) {
        ContentVersion clearedFile = new ContentVersion(
            ContentDocumentId = NULL,
            Title = fileName,
            PathOnClient = fileName,
            VersionData = fileBody
        );
        SFDCSecurityUtils.insertProxy(clearedFile);

        List<ContentVersion> contentVersionResult = DomainUtils.getFilesById(new Set<Id> {clearedFile.Id});
        List<ContentDocumentLink> junctionRecords = new List<ContentDocumentLink>();
        for (ContentVersion cv : contentVersionResult) {
            ContentDocumentLink junctionRecord = new ContentDocumentLink();
            junctionRecord.ContentDocumentId = cv.ContentDocumentId;
            junctionRecord.LinkedEntityId = bankRecId;
            junctionRecord.ShareType = 'I';
            junctionRecord.Visibility = 'AllUsers';
            junctionRecords.add(junctionRecord);
        }
        SFDCSecurityUtils.insertProxy(junctionRecords);
    }

    private static SaveResponse handleRunAutoClearJob(String bankRecId) {
        Bank_Reconciliation2__c bankRec = DomainUtils.getBankReconciliationById(bankRecId);
        Map<Id, Bank_Reconciliation2__c> bankRecMap = new Map<Id, Bank_Reconciliation2__c>();
        SaveResponse result = new SaveResponse();
        try {
            result = new SaveResponse (BankReconciliation.setStatus(bankRecId, BankReconciliation.Status.AUTO_CLEAR_RUNNING));
            if (result.isSuccess) {
                bankRecMap.put(bankRec.Id, bankRec);
                BankReconciliationActions.clearRelatedSourceDocuments(bankRecMap);
            }
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_WRITE, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }
}
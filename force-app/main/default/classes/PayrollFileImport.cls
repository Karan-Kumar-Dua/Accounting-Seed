public with sharing class PayrollFileImport {

    public List<PayrollImportLineWrapper> lineWrapperList {get; set;}

    public PayrollFileImport() {
        lineWrapperList = new List<PayrollImportLineWrapper>();
    }

    @AuraEnabled
    public static Map<String, String> getTransactionalLedger() {
        Map<String, String> ledgers = new Map<String, String>();
        Id defaultLedgerId = LedgerHandler.getLedgerId();
        Ledger__c defaultLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(defaultLedgerId);
        ledgers.put(defaultLedger.Name, defaultLedger.Id);
        for (Ledger__c eachLedger : LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers()) {
            if (!ledgers.keySet().contains(eachLedger.Name) && eachLedger.Active__c) {
                ledgers.put(eachLedger.Name, eachLedger.Id);
            }
        }
        return ledgers;
    }

    @AuraEnabled
    public static Map<String, String> getGlavsLabels() {
        Map<String, String> labels = new Map<String, String>();
        labels.put('gl variable 1', Schema.sObjectType.Journal_Entry_Line__c.fields.GL_Account_Variable_1__c.getLabel());
        labels.put('gl variable 2', Schema.sObjectType.Journal_Entry_Line__c.fields.GL_Account_Variable_2__c.getLabel());
        labels.put('gl variable 3', Schema.sObjectType.Journal_Entry_Line__c.fields.GL_Account_Variable_3__c.getLabel());
        labels.put('gl variable 4', Schema.sObjectType.Journal_Entry_Line__c.fields.GL_Account_Variable_4__c.getLabel());

        return labels;
    }

    public void saveFile(Set<Id> objectIds, String fileBody, String fileName) {
        try {
            ContentVersion clearedFile = new ContentVersion(
                ContentDocumentId = NULL,
                Title = fileName,
                PathOnClient = fileName,
                VersionData = Blob.valueOf(fileBody)
            );
            SFDCSecurityUtils.insertProxy(clearedFile);

            List<ContentVersion> contentVersionResult = DomainUtils.getFilesById(new Set<Id> {clearedFile.Id});

            List<ContentDocumentLink> junctionRecords = new List<ContentDocumentLink>();

            for (String objId : objectIds) {
                ContentDocumentLink junctionRecord = new ContentDocumentLink();
                junctionRecord.ContentDocumentId = contentVersionResult[0].ContentDocumentId;
                junctionRecord.LinkedEntityId = objId;
                junctionRecord.ShareType = 'I';
                junctionRecord.Visibility = 'AllUsers';
                junctionRecords.add(junctionRecord);
            }

            SFDCSecurityUtils.insertProxy(junctionRecords);
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    @AuraEnabled
    public static List<PayrollFileImport.PayrollImportLineWrapper> saveRecords(String dataTable, String fileBody, String fileName) {
        Savepoint sp = Database.setSavepoint();
        PayrollFileImport pfi = new PayrollFileImport();
        try {

            List<PayrollFileImport.PayrollImportLineWrapper> lineList = (List<PayrollFileImport.PayrollImportLineWrapper>) JSON.deserialize(dataTable, List<PayrollFileImport.PayrollImportLineWrapper>.class);
            pfi.lineWrapperList = lineList;

            for (PayrollImportLineWrapper wrp : pfi.lineWrapperList) {
                wrp.inspector = new PayrollFileImportInspector();
                wrp.obj = new Journal_Entry_Line__c();
                wrp.created = false;
            }

            pfi.setStatusForExistedRecords(pfi.lineWrapperList);

            Boolean isValidForInsert = true;
            for (PayrollImportLineWrapper wrappedLine : pfi.lineWrapperList) {
                if (!wrappedLine.inspector.isValidForCreation()) {
                    isValidForInsert = false;
                }
            }
            if (isValidForInsert) {
                pfi.createImportRecords();

                Boolean readyToAttachFile = true;
                Set<Id> jeIds = new Set<Id>();
                for (PayrollImportLineWrapper wrappedLine : pfi.lineWrapperList) {
                    if (!wrappedLine.inspector.isCreated()) {
                        readyToAttachFile = false;
                    }
                    jeIds.add(wrappedLine.obj.Journal_Entry__c);
                }

                if (readyToAttachFile) {
                    pfi.saveFile(jeIds, fileBody, fileName);
                }
            }

        }
        catch (Exception ex) {
            for (PayrollImportLineWrapper wrappedLine : pfi.lineWrapperList) {
                wrappedLine.inspector.addProcessResult(
                    new PayrollFileImportProcessResult(
                        false, NULL, StatusCode.SYSTEM_EXCEPTION, ex.getMessage()
                    )
                );
            }
            Database.rollback(sp);
        }

        for (PayrollImportLineWrapper wrappedLine : pfi.lineWrapperList) {
            wrappedLine.created = wrappedLine.inspector.isCreated();
            wrappedLine.status = wrappedLine.inspector.getCumulativeMessage();
        }

        return pfi.lineWrapperList;
    }

    private void setStatusForExistedRecords(List<PayrollImportLineWrapper> checkList) {
        PayrollImportLineCreationHandler creationHandler = new PayrollImportLineCreationHandler(checkList);
        creationHandler.validateAllLines();
    }

    private void createImportRecords() {
        //remove wrapped lines which did not pass preliminary validations
        List<PayrollImportLineWrapper> lineWrappersToInsert = new List<PayrollImportLineWrapper>();
        for (PayrollImportLineWrapper eachWrappedLine : lineWrapperList) {
            if (eachWrappedLine.inspector.isValidForCreation()) {
                lineWrappersToInsert.add(eachWrappedLine);
            }
        }
        PayrollImportLineCreationHandler creationHandler = new PayrollImportLineCreationHandler(lineWrappersToInsert);
        creationHandler.setLedgerId(lineWrapperList[0].ledgerId);
        creationHandler.insertRecords();

    }

    /*
    * ================================= INNER CLASSES ===================================
    * */
    public class PayrollFileImportException extends Exception {}

    public with sharing class PayrollFileImportInspector {
        public List<PayrollFileImportProcessResult> processResults;

        public PayrollFileImportInspector() {
            processResults = new List<PayrollFileImportProcessResult>();
        }

        public void addProcessResult(PayrollFileImportProcessResult res) {
            processResults.add(res);
        }

        //lack of processResults means line is without errors and it is ready for Insert operation
        public Boolean isValidForCreation() {
            return processResults.isEmpty();
        }

        public Boolean isCreated() {
            Boolean result = true;
            for (PayrollFileImportProcessResult processResult : processResults) {
                if (processResult.theStatusCode != StatusCode.CREATED) {
                    result = false;
                }
            }
            return result;
        }

        public String getCumulativeMessage() {
            String message = '';
            for (PayrollFileImportProcessResult processResult : processResults) {
                if (!String.isBlank(message)) {
                    message += '<br/>';
                }
                message += processResult.getMessage();
            }
            return message;
        }
    }

    public with sharing class PayrollFileImportProcessResult {
        public Boolean isSuccess {get; private set;}
        public String id {get; private set;}
        public StatusCode theStatusCode {get; private set;}
        public String customMessage {get; set;}

        public PayrollFileImportProcessResult(Boolean isSuccess, String id, StatusCode stCode, String customMessage) {
            this.isSuccess = isSuccess;
            this.id = id;
            this.theStatusCode = stCode;
            this.customMessage = customMessage;
        }

        public String getMessage() {
            String message = '';

            if (theStatusCode == StatusCode.CREATED) {
                message = '<span style="font-weight:bold;color:#390">'+Label.COMMON_CREATED+'<br/><a href="/' + id + '" target="_blank">'+Label.COMMON_VIEW_RECORD+'</a></span>';
            }
            else if (theStatusCode == StatusCode.GL_ACCOUNT_NOT_FOUND) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_GL_ACCOUNT_VALUES_MUST_EXIST+'</div>';
            }
            else if (theStatusCode == StatusCode.ACCOUNT_NOT_FOUND) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_ACCOUNT_VALUES_MUST_EXIST+'</div>';
            }
            else if (theStatusCode == StatusCode.PROJECT_NOT_FOUND) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_PROJECT_VALUES_MUST_EXIST+'</div>';
            }
            else if (theStatusCode == StatusCode.PROJECT_TASK_NOT_FOUND) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_PROJECT_TASK_VALUES_MUST_EXIST+'</div>';
            }
            else if (theStatusCode == StatusCode.PROJECT_TASK_REQUIRED) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_PROJECT_TASK_VALUE_REQUIRED+'</div>';
            }
            else if (theStatusCode == StatusCode.PROJECT_REQUIRED) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_PROJECT_VALUE_REQUIRED+'</div>';
            }
            else if (theStatusCode == StatusCode.GLAV_NOT_FOUND) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_GL_VARIABLE_DOES_NOT_EXIST+'</div>';
            }
            else if (theStatusCode == StatusCode.RECORD_EXISTS) {
                message = '<div style="font-weight:bold;color:#4585F4">'+Label.ERR_JE_VARIABLE_NAME_ALREADY_EXISTS+'<br/><a href="/' + id + '" target="_blank">'+Label.COMMON_VIEW_RECORD+'</a></div>';
            }
            else if (theStatusCode == StatusCode.REQUIRED_FIELD_ERROR) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_REQUIRED_COLUMNS_MISSING_VALUES+'<br/>' + customMessage + '</div>';
            }
            else if (theStatusCode == StatusCode.WRONG_DEBIT_CREDIT) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_DEBIT_CREDIT_NEEDED_NOT_BOTH+'</div>';
            }
            else if (theStatusCode == StatusCode.BALANCE_ERROR) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.ERR_BALANCE+'<br/>'+Label.ERR_DEBIT_CREDIT_MUST_BE_EQUAL+'</div>';
            }
            else if (theStatusCode == StatusCode.EMPTY_DEBIT_CREDIT) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_DEBIT_CREDIT_CANNOT_BE_EMPTY_FOR_JE_LINE+'</div>';
            }
            else if (theStatusCode == StatusCode.NEGATIVE_DEBIT_CREDIT) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_DEBIT_CREDIT_MUST_BE_POSITIVE_WITH_2_DECIMAL+'</div>';
            }
            else if (theStatusCode == StatusCode.WRONG_DATE_FORMAT) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_DATE_FORMAT+'</div>';
            }
            else if (theStatusCode == StatusCode.NO_PERIOD_EXIST) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_NO_ACCOUNTING_PERIOD_EXIST_DATE+'</div>';
            }
            else if (theStatusCode == StatusCode.NON_NUMERIC) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_NO_NON_NUMERIC_CHARACTER_DEBIT_CREDIT+'</div>';
            }
            else if (theStatusCode == StatusCode.CRUD_FLS_ERROR) {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.COMMON_NOT_VALID+'<br/>'+Label.ERR_NEED_CRUD_OR_FLS_PERMISSION + customMessage + ' '+ Label.COMMON_OBJECT + ' </div>';
            }
            else {
                message = '<div style="font-weight:bold;color:#c00;width:300px;overflow:scroll">'+Label.ERR_NOT_CREATED_EXCEPTION+'<br/>' + customMessage + '<br/></div>';
            }
            return message;
        }
    }

    public enum StatusCode {
        RECORD_EXISTS,
        CREATED,
        WRONG_DEBIT_CREDIT,
        REQUIRED_FIELD_ERROR,
        GL_ACCOUNT_NOT_FOUND,
        GLAV_NOT_FOUND,
        BALANCE_ERROR,
        SYSTEM_EXCEPTION,
        WRONG_DATE_FORMAT,
        EMPTY_DEBIT_CREDIT,
        NON_NUMERIC,
        NEGATIVE_DEBIT_CREDIT,
        NO_PERIOD_EXIST,
        CRUD_FLS_ERROR,
        ACCOUNT_NOT_FOUND,
        PROJECT_NOT_FOUND,
        PROJECT_TASK_NOT_FOUND,
        PROJECT_TASK_REQUIRED,
        PROJECT_REQUIRED
    }

    public with sharing class PayrollImportLineWrapper {
        @AuraEnabled
        public Journal_Entry_Line__c obj;
        @AuraEnabled
        public Integer lineNumber {get; set;}
        @AuraEnabled
        public String externalId {get; set;}
        @AuraEnabled
        public String masterRecordName {get; set;}
        @AuraEnabled
        public String transType {get; set;}
        @AuraEnabled
        public String stringTransDate {get; set;}
        @AuraEnabled
        public Date transDate {get; set;}
        @AuraEnabled
        public Decimal amount {get; set;}
        @AuraEnabled
        public String debitAmount {get; set;}
        @AuraEnabled
        public String creditAmount {get; set;}
        @AuraEnabled
        public String glAccountName {get; set;}
        @AuraEnabled
        public String glVariable1Name {get; set;}
        @AuraEnabled
        public String glVariable2Name {get; set;}
        @AuraEnabled
        public String glVariable3Name {get; set;}
        @AuraEnabled
        public String glVariable4Name {get; set;}
        @AuraEnabled
        public String status {get; set;}
        @AuraEnabled
        public Boolean created {get; set;}
        @AuraEnabled
        public String ledgerId {get; set;}
        @AuraEnabled
        public String accountName {get; set;}
        @AuraEnabled
        public String projectName {get; set;}
        @AuraEnabled
        public String projectTaskName {get; set;}

        public PayrollFileImportInspector inspector {get; set;}

        public PayrollImportLineWrapper(Integer lineNumber,
                                        String masterRecordName,
                                        String glAccountName,
                                        String stringTransDate,
                                        String debitAmount,
                                        String creditAmount,
                                        String referenceValue,
                                        String glVariable1Name,
                                        String glVariable2Name,
                                        String glVariable3Name,
                                        String glVariable4Name) {

            this.lineNumber = lineNumber;
            this.masterRecordName = masterRecordName;
            this.stringTransDate = stringTransDate;
            this.glAccountName = glAccountName;
            this.debitAmount = debitAmount;
            this.creditAmount = creditAmount;
            this.externalId = referenceValue;
            this.glVariable1Name = glVariable1Name;
            this.glVariable2Name = glVariable2Name;
            this.glVariable3Name = glVariable3Name;
            this.glVariable4Name = glVariable4Name;
            this.inspector = new PayrollFileImportInspector();
            this.obj = new Journal_Entry_Line__c();
        }

    }

    public with sharing class PayrollImportLineCreationHandler {

        private String ledgerId;
        private String currencyIsoCode;
        private Boolean IS_MULTI_CURRENCY_ENABLED;

        public List<PayrollImportLineWrapper> wrappedPayrollImportLines;
        public List<Journal_Entry_Line__c> jeLinesToInsert;
        public List<Journal_Entry__c> jesToInsert;

        public PayrollImportLineCreationHandler(List<PayrollImportLineWrapper> wrappedPayrollImportLines) {
            this.wrappedPayrollImportLines = wrappedPayrollImportLines;
            IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;
            jeLinesToInsert = new List<Journal_Entry_Line__c>();
            jesToInsert = new List<Journal_Entry__c>();
        }

        public void setLedgerId(String ledgerId) {
            this.ledgerId = ledgerId;
        }

        public String getLedgerId() {
            return ledgerId;
        }

        public void insertRecords() {
            setCurrencyFromLedger();
            bindEachLineWithGLAccount();
            bindEachLineWithGLAVs();
            bindEachLineWithAccount();
            bindEachLineWithProjectAndProjectTask();
            bindWithNewMasterRecords();

            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (wrappedLine.obj != NULL
                    && wrappedLine.obj.Journal_Entry__c != NULL
                    && wrappedLine.obj.GL_Account__c != NULL) {

                    jeLinesToInsert.add(wrappedLine.obj);
                }
            }

            if (!jeLinesToInsert.isEmpty()) {
                try {
                    SFDCSecurityUtils.insertCheckCRUDAndFLS(jeLinesToInsert, new List<String>{
                        'Journal_Entry__c',
                        'GL_Account__c',
                        'Date__c',
                        'Reference__c',
                        'Debit__c',
                        'Credit__c',
                        'GL_Account_Variable_1__c',
                        'GL_Account_Variable_2__c',
                        'GL_Account_Variable_3__c',
                        'GL_Account_Variable_4__c'

                    });
                    for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                        wrappedLine.inspector.addProcessResult(
                            new PayrollFileImportProcessResult(
                                true, wrappedLine.obj.Journal_Entry__c, StatusCode.CREATED, NULL
                            )
                        );
                    }
                }
                catch (Exception ex) {
                    throw ex;
                }
            }
        }

        public void validateAllLines() {
            validateRequiredValues();
            validateExistedRecords();
            checkJournalEntryBalance();
            validateGLAccount();
            validateGLAVs();
            validateAccount();
            validateProjectAndProjectTask();
        }

        private String convertDecimalStringByLocale(String decimalString) {
            if (decimalString.contains(',') || decimalString.contains('.')) {
                String fraction = decimalString.replace(',','.').substringAfterLast('.');
                Integer i = decimalString.length();
                return decimalString.subString(0, i - (fraction.length() + 1)).replace(' ','').replace(',','').replace('\'','').replace('.','') + '.' + decimalString.subString(i - fraction.length(), i);
            }
            else {
                return decimalString;
            }
        }

        private void validateRequiredValues() {

            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                List<String> missingFields = new List<String>();

                if (String.isBlank(wrappedLine.masterRecordName)) {
                    missingFields.add(Label.COMMON_JOURNAL_ENTRY);
                }

                if (wrappedLine.stringTransDate == NULL) {
                    missingFields.add(Label.COMMON_DATE);
                }

                if (String.isBlank(wrappedLine.glAccountName)) {
                    missingFields.add(Label.COMMON_GL_ACCOUNT);
                }

                try {
                    if (!String.isBlank(wrappedLine.debitAmount)) {
                        Decimal.valueOf(convertDecimalStringByLocale(wrappedLine.debitAmount));
                        wrappedLine.debitAmount = convertDecimalStringByLocale(wrappedLine.debitAmount);
                    }
                    if (!String.isBlank(wrappedLine.creditAmount)) {
                        Decimal.valueOf(convertDecimalStringByLocale(wrappedLine.creditAmount));
                        wrappedLine.creditAmount = convertDecimalStringByLocale(wrappedLine.creditAmount);
                    }

                    if ((String.isBlank(wrappedLine.debitAmount)
                        || (!String.isBlank(wrappedLine.debitAmount) && Decimal.valueOf(wrappedLine.debitAmount) == 0))
                        && (String.isBlank(wrappedLine.creditAmount)
                        || (!String.isBlank(wrappedLine.creditAmount) && Decimal.valueOf(wrappedLine.creditAmount) == 0))) {
                        wrappedLine.inspector.addProcessResult(
                            new PayrollFileImportProcessResult(
                                false, NULL, StatusCode.EMPTY_DEBIT_CREDIT, NULL
                            )
                        );
                    }

                    if ((!String.isBlank(wrappedLine.debitAmount)
                        && (Decimal.valueOf(wrappedLine.debitAmount) < 0 || Decimal.valueOf(wrappedLine.debitAmount).scale() > 2))
                        || (!String.isBlank(wrappedLine.creditAmount)
                        && (Decimal.valueOf(wrappedLine.creditAmount) < 0 || Decimal.valueOf(wrappedLine.creditAmount).scale() > 2))) {
                        wrappedLine.inspector.addProcessResult(
                            new PayrollFileImportProcessResult(
                                false, NULL, StatusCode.NEGATIVE_DEBIT_CREDIT, NULL
                            )
                        );
                    }

                    if ((!String.isBlank(wrappedLine.debitAmount) && Decimal.valueOf(wrappedLine.debitAmount) != 0)
                        && (!String.isBlank(wrappedLine.creditAmount) && Decimal.valueOf(wrappedLine.creditAmount) != 0)) {
                        wrappedLine.transType = NULL;
                        wrappedLine.inspector.addProcessResult(
                            new PayrollFileImportProcessResult(
                                false, NULL, StatusCode.WRONG_DEBIT_CREDIT, NULL
                            )
                        );
                    }
                    else if (!String.isBlank(wrappedLine.debitAmount) && Decimal.valueOf(wrappedLine.debitAmount) != 0) {
                        wrappedLine.transType = 'DEBIT';
                        wrappedLine.amount = Decimal.valueOf(wrappedLine.debitAmount).setScale(2, System.RoundingMode.HALF_UP);
                        wrappedLine.obj.Debit__c =  wrappedLine.amount ;
                    }
                    else if (!String.isBlank(wrappedLine.creditAmount) && Decimal.valueOf(wrappedLine.creditAmount) != 0) {
                        wrappedLine.transType = 'CREDIT';
                        wrappedLine.amount = Decimal.valueOf(wrappedLine.creditAmount).setScale(2, System.RoundingMode.HALF_UP);
                        wrappedLine.obj.Credit__c =  wrappedLine.amount ;
                    }
                }
                catch (TypeException ex) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.NON_NUMERIC, NULL
                        )
                    );
                }

                if (!missingFields.isEmpty()) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.REQUIRED_FIELD_ERROR, String.join(missingFields, ',')
                        )
                    );
                }

                try {
                    wrappedLine.transDate = Date.parse(wrappedLine.stringTransDate);
                    Accounting_Period__c selectedAccountingPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(wrappedLine.transDate);
                    if (selectedAccountingPeriod == NULL) {
                        wrappedLine.inspector.addProcessResult(
                            new PayrollFileImportProcessResult(
                                false, NULL, StatusCode.NO_PERIOD_EXIST, NULL
                            )
                        );
                    }
                }
                catch (TypeException ex) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.WRONG_DATE_FORMAT, NULL
                        )
                    );
                }
            }
        }

        private void validateExistedRecords() {
            List<String> jeNamesInFile = new List<String>();

            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.masterRecordName)) {
                    jeNamesInFile.add(wrappedLine.masterRecordName);
                }
            }

            Map<String, Journal_Entry__c> jEntriesInDBByName = new Map<String, Journal_Entry__c>();
            for (Journal_Entry__c jEntry : DomainUtils.getJournalEntryByName(jeNamesInFile)) {
                jEntriesInDBByName.put(jEntry.Name, jEntry);
            }

            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.masterRecordName) && jEntriesInDBByName.containsKey(wrappedLine.masterRecordName)) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            true, jEntriesInDBByName.get(wrappedLine.masterRecordName).Id, StatusCode.RECORD_EXISTS, NULL
                        )
                    );
                }
            }
        }

        private void checkJournalEntryBalance() {
            //map all lines from file by JE name
            Map<String, List<PayrollImportLineWrapper>> lineByNameMapping = new Map<String, List<PayrollImportLineWrapper>>();
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.masterRecordName) && !String.isBlank(wrappedLine.transType)) {
                    if (lineByNameMapping.containsKey(wrappedLine.masterRecordName)) {
                        lineByNameMapping.get(wrappedLine.masterRecordName).add(wrappedLine);
                    }
                    else {
                        lineByNameMapping.put(wrappedLine.masterRecordName, new List<PayrollImportLineWrapper>{wrappedLine});
                    }
                }
            }
            //go through all mappings and check balance (expected is 0)
            for (String jeName : lineByNameMapping.keySet()) {
                Decimal balance = 0;
                for (PayrollImportLineWrapper line : lineByNameMapping.get(jeName)) {
                    Decimal debitAmount = (line.transType == 'DEBIT') ? line.amount : 0;
                    Decimal creditAmount = (line.transType == 'CREDIT') ? line.amount : 0;
                    balance = balance + debitAmount - creditAmount;
                }

                if (balance != 0) {
                    for (PayrollImportLineWrapper line : lineByNameMapping.get(jeName)) {
                        line.inspector.addProcessResult(
                            new PayrollFileImportProcessResult(
                                false, NULL, StatusCode.BALANCE_ERROR, NULL
                            )
                        );
                    }
                }
            }

        }

        private void validateGLAccount() {
            //get all GL Account names from wrapped lines and query them to check existence
            List<String> glAccountNames = new List<String>();
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.glAccountName)) {
                    glAccountNames.add(wrappedLine.glAccountName);
                }
            }

            //map all queried GL accounts by name
            Map<String, GL_Account__c> glAccountIdsByName = new Map<String, GL_Account__c>();

            try {
                for (GL_Account__c glAccount : queryGLAccounts(glAccountNames)) {
                    glAccountIdsByName.put(glAccount.Name.toLowerCase(), glAccount);
                }
            }
            catch (Exception ex) {
                for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.CRUD_FLS_ERROR, Label.COMMON_GL_ACCOUNT
                        )
                    );
                }

            }

            //mark wrapped line with appropriate error status
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.glAccountName) && glAccountIdsByName.get(wrappedLine.glAccountName.toLowerCase()) == NULL) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.GL_ACCOUNT_NOT_FOUND, NULL
                        )
                    );
                }
                else {
                    if (!String.isBlank(wrappedLine.glAccountName)) {
                        wrappedLine.glAccountName = glAccountIdsByName.get(wrappedLine.glAccountName.toLowerCase()).Name;
                    }
                }
            }
        }

        private void validateGLAVs() {
            //get all GLAVs names from wrapped lines and query them to check existence
            Set<String> glavNames = new Set<String>();
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.glVariable1Name)) {
                    glavNames.add(wrappedLine.glVariable1Name);
                }
                if (!String.isBlank(wrappedLine.glVariable2Name)) {
                    glavNames.add(wrappedLine.glVariable2Name);
                }
                if (!String.isBlank(wrappedLine.glVariable3Name)) {
                    glavNames.add(wrappedLine.glVariable3Name);
                }
                if (!String.isBlank(wrappedLine.glVariable4Name)) {
                    glavNames.add(wrappedLine.glVariable4Name);
                }
            }

            //map all queried GLAVS by name
            Map<String, Accounting_Variable__c> glavsByName = new Map<String, Accounting_Variable__c>();

            try {
                for (Accounting_Variable__c glav : queryAccountingVariables(glavNames)) {
                    glavsByName.put(glav.Name.toLowerCase(), glav);
                }
            }
            catch (Exception ex) {
                for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.CRUD_FLS_ERROR, Label.COMMON_GL_ACCOUNT_VARIABLE
                        )
                    );
                }

            }

            //mark wrapped line with appropriate error status
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if ((!String.isBlank(wrappedLine.glVariable1Name.toLowerCase())
                        && (glavsByName.get(wrappedLine.glVariable1Name.toLowerCase()) == NULL
                            || glavsByName.get(wrappedLine.glVariable1Name.toLowerCase()).Type__c != 'GL Account Variable 1'))
                    || (!String.isBlank(wrappedLine.glVariable2Name.toLowerCase())
                        && (glavsByName.get(wrappedLine.glVariable2Name.toLowerCase()) == NULL
                        || glavsByName.get(wrappedLine.glVariable2Name.toLowerCase()).Type__c != 'GL Account Variable 2'))
                    || (!String.isBlank(wrappedLine.glVariable3Name.toLowerCase())
                        && (glavsByName.get(wrappedLine.glVariable3Name.toLowerCase()) == NULL
                        || glavsByName.get(wrappedLine.glVariable3Name.toLowerCase()).Type__c != 'GL Account Variable 3'))
                    || (!String.isBlank(wrappedLine.glVariable4Name.toLowerCase())
                        && (glavsByName.get(wrappedLine.glVariable4Name.toLowerCase()) == NULL
                        || glavsByName.get(wrappedLine.glVariable4Name.toLowerCase()).Type__c != 'GL Account Variable 4'))) {


                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.GLAV_NOT_FOUND, NULL
                        )
                    );
                }
                else {
                    if (!String.isBlank(wrappedLine.glVariable1Name.toLowerCase())) {
                        wrappedLine.glVariable1Name = glavsByName.get(wrappedLine.glVariable1Name.toLowerCase()).Name;
                    }
                    if (!String.isBlank(wrappedLine.glVariable2Name.toLowerCase())) {
                        wrappedLine.glVariable2Name = glavsByName.get(wrappedLine.glVariable2Name.toLowerCase()).Name;
                    }
                    if (!String.isBlank(wrappedLine.glVariable3Name.toLowerCase())) {
                        wrappedLine.glVariable3Name = glavsByName.get(wrappedLine.glVariable3Name.toLowerCase()).Name;
                    }
                    if (!String.isBlank(wrappedLine.glVariable4Name.toLowerCase())) {
                        wrappedLine.glVariable4Name = glavsByName.get(wrappedLine.glVariable4Name.toLowerCase()).Name;
                    }
                }

            }

        }

        private void validateAccount() {
            //get all Account names from wrapped lines and query them to check existence
            List<String> accountNames = new List<String>();
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.accountName)) {
                    accountNames.add(wrappedLine.accountName);
                }
            }

            //map all queried Accounts by name
            Map<String, Account> accountIdsByName = new Map<String, Account>();

            try {
                for (Account account : queryAccounts(accountNames)) {
                    accountIdsByName.put(account.Name.toLowerCase(), account);
                }
            }
            catch (Exception ex) {
                for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.CRUD_FLS_ERROR, Label.COMMON_ACCOUNT
                        )
                    );
                }

            }

            //mark wrapped line with appropriate error status
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.accountName) && accountIdsByName.get(wrappedLine.accountName.toLowerCase()) == NULL) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.ACCOUNT_NOT_FOUND, NULL
                        )
                    );
                }
                else {
                    if (!String.isBlank(wrappedLine.accountName)) {
                        wrappedLine.accountName = accountIdsByName.get(wrappedLine.accountName.toLowerCase()).Name;
                    }
                }
            }
        }

        private void validateProjectAndProjectTask() {
            //get all Project names from wrapped lines and query them to check existence
            List<String> projectNames = new List<String>();
            List<String> projectTaskNames = new List<String>();
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.projectName)) {
                    projectNames.add(wrappedLine.projectName);
                }
                if (!String.isBlank(wrappedLine.projectTaskName)) {
                    projectTaskNames.add(wrappedLine.projectTaskName);
                }
            }

            //map all queried Project and Project Task by name
            Map<String, Project__c> projectIdsByName = new Map<String, Project__c>();
            Map<String, Project_Task__c> projectTaskIdsByName = new Map<String, Project_Task__c>();

            try {
                for (Project__c project : queryProject(projectNames)) {
                    projectIdsByName.put(project.Name.toLowerCase(), project);
                }
                for (Project_Task__c projectTask : queryProjectTask(projectTaskNames)) {
                    projectTaskIdsByName.put(projectTask.Name.toLowerCase(), projectTask);
                }
            }
            catch (Exception ex) {
                for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.CRUD_FLS_ERROR, Label.COMMON_PROJECT_PROJECTTASK
                        )
                    );
                }

            }

            //mark wrapped line with appropriate error status
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.projectName) && projectIdsByName.get(wrappedLine.projectName.toLowerCase()) == NULL) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.PROJECT_NOT_FOUND, NULL
                        )
                    );
                }
                else if (!String.isBlank(wrappedLine.projectTaskName) && projectTaskIdsByName.get(wrappedLine.projectTaskName.toLowerCase()) == NULL) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.PROJECT_TASK_NOT_FOUND, NULL
                        )
                    );
                }
                else if (!String.isBlank(wrappedLine.projectName) && String.isBlank(wrappedLine.projectTaskName)) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.PROJECT_TASK_REQUIRED, NULL
                        )
                    );
                }
                else if (String.isBlank(wrappedLine.projectName) && !String.isBlank(wrappedLine.projectTaskName)) {
                    wrappedLine.inspector.addProcessResult(
                        new PayrollFileImportProcessResult(
                            false, NULL, StatusCode.PROJECT_REQUIRED, NULL
                        )
                    );
                }
                else {
                    if (!String.isBlank(wrappedLine.projectName)) {
                        wrappedLine.projectName = projectIdsByName.get(wrappedLine.projectName.toLowerCase()).Name;
                    }
                    if (!String.isBlank(wrappedLine.projectTaskName)) {
                        wrappedLine.projectTaskName = projectTaskIdsByName.get(wrappedLine.projectTaskName.toLowerCase()).Name;
                    }
                }
            }
        }

        private void setCurrencyFromLedger() {
            if (IS_MULTI_CURRENCY_ENABLED) {
                currencyIsoCode = (String) LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(ledgerId).get('CurrencyIsoCode');
            }
        }

        private void bindEachLineWithGLAccount() {
            //get all GL Account names from wrapped lines and query them to have Ids
            List<String> glAccountNames = new List<String>();
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.glAccountName)) {
                    glAccountNames.add(wrappedLine.glAccountName);
                }
            }

            //map all queried GL accounts by name
            Map<String, Id> glAccountIdsByName = new Map<String, Id>();
            for (GL_Account__c glAccount : DomainUtils.getGlAccountsByName(glAccountNames)) {
                glAccountIdsByName.put(glAccount.Name, glAccount.Id);
            }

            //put appropriate GL Account Id into GL Account lookup field on JE Line record
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.glAccountName)) {
                    wrappedLine.obj.GL_Account__c = glAccountIdsByName.get(wrappedLine.glAccountName);
                }
            }
        }

        private void bindEachLineWithAccount() {
            //get all Account names from wrapped lines and query them to have Ids
            Set<String> accountNames = new Set<String>();
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.accountName)) {
                    accountNames.add(wrappedLine.accountName);
                }
            }

            //map all queried accounts by name
            Map<String, Id> accountIdsByName = new Map<String, Id>();
            for (Account account : DomainUtils.getAccountsByName(accountNames)) {
                accountIdsByName.put(account.Name, account.Id);
            }

            //put appropriate Account Id into GL Account lookup field on JE Line record
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.accountName)) {
                    wrappedLine.obj.Account__c = accountIdsByName.get(wrappedLine.accountName);
                }
            }
        }

        private void bindEachLineWithProjectAndProjectTask() {
            List<String> projectNames = new List<String>();
            List<String> projectTaskNames = new List<String>();
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.projectName)) {
                    projectNames.add(wrappedLine.projectName);
                }
                if (!String.isBlank(wrappedLine.projectTaskName)) {
                    projectTaskNames.add(wrappedLine.projectTaskName);
                }
            }

            Map<String, Id> projectIdsByName = new Map<String, Id>();
            Map<String, Id> projectTaskIdsByName = new Map<String, Id>();
            for (Project__c project : queryProject(projectNames)) {
                projectIdsByName.put(project.Name, project.Id);
            }
            for (Project_Task__c projectTask : queryProjectTask(projectTaskNames)) {
                projectTaskIdsByName.put(projectTask.Name, projectTask.Id);
            }

            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.projectName)) {
                    wrappedLine.obj.Project__c = projectIdsByName.get(wrappedLine.projectName);
                }
                if (!String.isBlank(wrappedLine.projectTaskName)) {
                    wrappedLine.obj.Project_Task__c = projectTaskIdsByName.get(wrappedLine.projectTaskName);
                }
            }
        }

        private void bindEachLineWithGLAVs() {
            //get all GLAVs names from wrapped lines and query them to have an ID
            Set<String> glavNames = new Set<String>();
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.glVariable1Name)) {
                    glavNames.add(wrappedLine.glVariable1Name);
                }
                if (!String.isBlank(wrappedLine.glVariable2Name)) {
                    glavNames.add(wrappedLine.glVariable2Name);
                }
                if (!String.isBlank(wrappedLine.glVariable3Name)) {
                    glavNames.add(wrappedLine.glVariable3Name);
                }
                if (!String.isBlank(wrappedLine.glVariable4Name)) {
                    glavNames.add(wrappedLine.glVariable4Name);
                }
            }

            //map all queried GLAVS by name
            Map<String, Accounting_Variable__c> glavsByName = new Map<String, Accounting_Variable__c>();
            for (Accounting_Variable__c glav : DomainUtils.getGLAVsByName(glavNames)) {
                glavsByName.put(glav.Name, glav);
            }

            //put appropriate GLAVs Id into GLAV lookup field on JE Line record
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!String.isBlank(wrappedLine.glVariable1Name)
                        && glavsByName.get(wrappedLine.glVariable1Name) != NULL
                        && glavsByName.get(wrappedLine.glVariable1Name).Type__c == 'GL Account Variable 1') {

                    wrappedLine.obj.GL_Account_Variable_1__c = glavsByName.get(wrappedLine.glVariable1Name).Id;
                }

                if (!String.isBlank(wrappedLine.glVariable2Name)
                        && glavsByName.get(wrappedLine.glVariable2Name) != NULL
                        && glavsByName.get(wrappedLine.glVariable2Name).Type__c == 'GL Account Variable 2') {

                    wrappedLine.obj.GL_Account_Variable_2__c = glavsByName.get(wrappedLine.glVariable2Name).Id;
                }

                if (!String.isBlank(wrappedLine.glVariable3Name)
                        && glavsByName.get(wrappedLine.glVariable3Name) != NULL
                        && glavsByName.get(wrappedLine.glVariable3Name).Type__c == 'GL Account Variable 3') {

                    wrappedLine.obj.GL_Account_Variable_3__c = glavsByName.get(wrappedLine.glVariable3Name).Id;
                }

                if (!String.isBlank(wrappedLine.glVariable4Name)
                        && glavsByName.get(wrappedLine.glVariable4Name) != NULL
                        && glavsByName.get(wrappedLine.glVariable4Name).Type__c == 'GL Account Variable 4') {

                    wrappedLine.obj.GL_Account_Variable_4__c = glavsByName.get(wrappedLine.glVariable4Name).Id;
                }
            }
        }

        private void bindWithNewMasterRecords() {
            Map<String, Date> jeNameDate = new Map<String, Date>();
            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                if (!jeNameDate.keySet().contains(wrappedLine.masterRecordName)) {
                    jeNameDate.put(wrappedLine.masterRecordName, wrappedLine.transDate);
                }
                else {
                    if (jeNameDate.get(wrappedLine.masterRecordName) < wrappedLine.transDate) {
                        jeNameDate.put(wrappedLine.masterRecordName, wrappedLine.transDate);
                    }
                }
            }

            //create and insert new master records
            for (String jeName : jeNameDate.keySet()) {
                Journal_Entry__c tempJEntry = new Journal_Entry__c(
                    Name = jeName,
                    Journal_Date__c = jeNameDate.get(jeName),
                    Status__c = 'Approved',
                    Ledger__c = ledgerId,
                    Source__c = JournalEntryActions.SOURCE_IMPORT
                );
                if (IS_MULTI_CURRENCY_ENABLED) {
                    tempJEntry.put('currencyIsoCode', currencyIsoCode);
                }
                jesToInsert.add(tempJEntry);
            }

            SFDCSecurityUtils.insertCheckCRUDAndFLS(jesToInsert, new List<String>{
                'Journal_Date__c',
                'Status__c',
                'Ledger__c'
            });

            Map<String, Id> journalEntryIdsByName = new Map<String, Id>();
            for (Journal_Entry__c existedJE : jesToInsert) {
                journalEntryIdsByName.put(existedJE.Name, existedJE.Id);
            }

            for (PayrollImportLineWrapper wrappedLine : wrappedPayrollImportLines) {
                wrappedLine.obj.Journal_Entry__c = journalEntryIdsByName.get(wrappedLine.masterRecordName);
                wrappedLine.obj.Date__c = jeNameDate.get(wrappedLine.masterRecordName);
                wrappedLine.obj.Reference__c = wrappedLine.externalId;
            }
        }

        private List<GL_Account__c> queryGLAccounts(List<String> glAccountNames) {
            List<String> queryFields = new List<String>{
                'Id',
                'Name'
            };

            String queryCondition = 'Name IN :glAccountNames';
            SOQLBuilder theQuery = new SOQLBuilder(GL_Account__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            return (List<GL_Account__c>) Database.query(theQuery.toSOQL());
        }

        private List<Accounting_Variable__c> queryAccountingVariables(Set<String> names) {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Type__c'
            };

            String queryCondition = 'Name IN :names';
            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Accounting_Variable__c', 'LastModifiedDate', SOQLBuilder.SortOrder.ASCENDING);

            SOQLBuilder theQuery = new SOQLBuilder(Accounting_Variable__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .addOrdering(ordering);

            return (List<Accounting_Variable__c>) Database.query(theQuery.toSOQL());
        }

        private List<Account> queryAccounts(List<String> accountNames) {
            List<String> queryFields = new List<String>{
                'Id',
                'Name'
            };

            String queryCondition = 'Name IN :accountNames';
            SOQLBuilder theQuery = new SOQLBuilder(Account.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            return (List<Account>) Database.query(theQuery.toSOQL());
        }

        private List<Project__c> queryProject(List<String> projectNames) {
            List<String> queryFields = new List<String>{
                'Id',
                'Name'
            };

            String queryCondition = 'Name IN :projectNames';
            SOQLBuilder theQuery = new SOQLBuilder(Project__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            return (List<Project__c>) Database.query(theQuery.toSOQL());
        }

        private List<Project_Task__c> queryProjectTask(List<String> projectTaskNames) {
            List<String> queryFields = new List<String>{
                'Id',
                'Name'
            };

            String queryCondition = 'Name IN :projectTaskNames';
            SOQLBuilder theQuery = new SOQLBuilder(Project_Task__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            return (List<Project_Task__c>) Database.query(theQuery.toSOQL());
        }

    }

}
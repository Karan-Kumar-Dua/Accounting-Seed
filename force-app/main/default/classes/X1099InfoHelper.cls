public with sharing class X1099InfoHelper {

    public static final String SAVE_ERROR = Label.ERR_SAVE;
    public static final Integer MAX_ERRORS_DISPLAYED = 5;
    public static final String SAVE_ERROR_RECORD_DETAIL = Label.ERR_SAVE_ERROR_RECORD_DETAIL;
    public static final String SAVE_ERROR_TRUNC = Label.ERR_SAVE_ERROR_TRUNC;
    public class SaveResponse {
        @AuraEnabled
        public Boolean isSuccess;
        @AuraEnabled
        public Integer successfulRecordCount;
        @AuraEnabled
        public List<String> errors;
        
        public SaveResponse(List<String> errors, Integer successfulRecordCount) {
            this.isSuccess = errors == null || errors.size() == 0;
            this.errors = errors;        
            this.successfulRecordCount = successfulRecordCount;
        }
    }

    public class X1099Response {
        @AuraEnabled
        public Boolean isSuccess;
        @AuraEnabled
        public List<String> errors;
        @AuraEnabled
        public Boolean X1099Vendor;
        @AuraEnabled
        public String taxpayerId;
        @AuraEnabled
        public String default1099Box;        
        @AuraEnabled
        public String default1099Type;        
        
        public X1099Response(List<String> errors) {
            this.isSuccess = errors == null || errors.size() == 0;
            this.errors = errors;    
        }
        
        public X1099Response(List<String> errors, 
                            Boolean X1099Vendor, 
                            String taxpayerId, 
                            String default1099Box) {
            this.isSuccess = errors == null || errors.size() == 0;
            this.errors = errors;                    
            this.X1099Vendor = X1099Vendor;
            this.taxpayerId = taxpayerId;
            this.default1099Box = default1099Box;
            if (String.isNotEmpty(default1099Box)) {
                this.default1099Type = getFormCategoryById(default1099Box).Form_Type__r.Id;
            }
        }
    }
    
    @AuraEnabled(cacheable=true) 
    public static List<Form_Type__mdt> getFormTypes(Integer effectiveYear) {
        return DomainUtils.getFormTypesByEffectiveYear(effectiveYear);
    }

    public static List<Form_Type__mdt> getFormTypesOrderByTypeYearASC(Integer effectiveYear) {
        return DomainUtils.getFormTypesOrderByTypeYearASC(effectiveYear);
    }

    @AuraEnabled(cacheable=true) 
    public static List<Form_Category__mdt> getFormCategoriesByFormType(String formTypeId){
        if (formTypeId != '') {
            return DomainUtils.getFormCategories(formTypeId);
        } else {
            return new List<Form_Category__mdt>();
        }
    }

    @AuraEnabled
    public static X1099Response getSingleRecordValues(Id recordId) {
        try {
            Schema.SObjectType objType = Id.valueOf(recordId).getSobjectType();
            SObject sobj = getSingleRecordValuesHelper(recordId, objType, new List<String> {
                'X1099_Vendor__c',
                'Taxpayer_Identification_Number__c',
                'Default_Form_Category_Id__c'
            });
            return new X1099Response(
                null, 
                (Boolean)sobj.get('X1099_Vendor__c'),
                (String)sobj.get('Taxpayer_Identification_Number__c'),
                (String)sobj.get('Default_Form_Category_Id__c'));       
        } catch (exception ex) {
            return new X1099Response(new List<String> {ex.getMessage()});
        } 
    }

    @AuraEnabled
    public static X1099Response get1099InfoForCD(Id recordId) {
        try {
            Schema.SObjectType objType = Id.valueOf(recordId).getSobjectType();
            SObject sobj = getSingleRecordValuesHelper(recordId, objType, new List<String> {
                'Form_Category_Id__c'
            });
            return new X1099Response(null, null, null, (String)sobj.get('Form_Category_Id__c'));
        } catch (Exception ex) {
            return new X1099Response(new List<String> {ex.getMessage()});
        }
    }

    @AuraEnabled
    public static SaveResponse save(
            List<Id> recordIds, 
            Boolean enable1099Vendor, 
            String defaultForm1099TypeId, 
            String defaultForm1099BoxId, 
            String taxpayerIdentificationNumber){

        if (recordIds.size() == 0) {
            return new SaveResponse(new String[]{}, 0);
        }
        if (String.isNotEmpty(defaultForm1099TypeId) && String.isEmpty(defaultForm1099BoxId)) {
            return new SaveResponse(new String[] {SAVE_ERROR}, 0);
        }
        Savepoint sp = Database.setSavepoint();
        try {            
            String formCategoryLabel = getFormCategoryLabel(defaultForm1099BoxId);

            Schema.SObjectType objType = Id.valueOf(new List<Id>(recordIds)[0]).getSobjectType();
            List<SObject> recordsToUpdate = (List<SObject>)Type.forName('List<' + objType + '>').newInstance();
            for(Integer i = 0; i< recordIds.size(); i++) {
                SObject record = objType.newSObject(recordIds[i]);
                record.put('X1099_Vendor__c', enable1099Vendor);
                record.put('Default_Form_Category_Id__c', defaultForm1099BoxId);
                record.put('Default_Form_1099_Box__c', formCategoryLabel);
                if (recordIds.size() == 1) {
                    record.put('Taxpayer_Identification_Number__c', taxpayerIdentificationNumber);
                }
                recordsToUpdate.add(record);
            }

            //updateRecords
            List<String> updateFields = new List<String>{
                'X1099_Vendor__c',
                'Default_Form_1099_Box__c',
                'Default_Form_Category_Id__c'
            };
            if (recordIds.size() == 1) {
                updateFields.add('Taxpayer_Identification_Number__c');
            }

            List<Database.SaveResult> result = SFDCSecurityUtils.updateCheckCRUDAndFLS(recordsToUpdate, updateFields, false);            
            return processSaveResults(result, recordsToUpdate);
        } catch (Exception ex) {
            Database.rollback(sp);
            return new SaveResponse(new String[] {ex.getMessage()}, 0);
        }  
    }
  
    @AuraEnabled
    public static SaveResponse save1099InfoForCDs(
            List<Id> recordIds, 
            String form1099TypeId, 
            String form1099BoxId) {

        if (recordIds == null || recordIds.size() == 0) {
            return new SaveResponse(new String[]{}, 0);
        }
        if (String.isNotEmpty(form1099TypeId) && String.isEmpty(form1099BoxId)) {
            return new SaveResponse(new String[] {SAVE_ERROR}, 0); 
        }

        Savepoint sp = Database.setSavepoint();

        try {
            String formCategoryLabel = getFormCategoryLabel(form1099BoxId);

            List<Cash_Disbursement__c> recordsToUpdate = new List<Cash_Disbursement__c>();
            for(Id recordId : recordIds) {
                recordsToUpdate.add(new Cash_Disbursement__c(
                    Id = recordId,
                    Form_1099_Box__c = formCategoryLabel,
                    Form_Category_Id__c = form1099BoxId
                ));
            }

            //updateRecords
            List<String> updateFields = new List<String>{
                'Form_1099_Box__c',
                'Form_Category_Id__c'
            };

            List<Database.SaveResult> result = SFDCSecurityUtils.updateCheckCRUDAndFLS(recordsToUpdate, updateFields, false);
            return processSaveResults(result, recordsToUpdate);
        } catch (Exception ex) {
            Database.rollback(sp);
            return new SaveResponse(new String[] {ex.getMessage()}, 0); 
        }
    }

    private static SaveResponse processSaveResults(List<Database.SaveResult> saveResults, List<SObject> updates) {
        Integer errorCount = 0;
        List<String> errors = new List<String>();
        
        Id currentId;
        Database.SaveResult sr;
        for (Integer i=0; i<saveResults.size(); i++) {
            sr = saveResults[i];
            if (!sr.isSuccess()) {
                currentId = sr.getId() == null ? updates[i].Id : sr.getId();             
                for (Database.Error err : sr.getErrors()) {
                    if (errorCount < MAX_ERRORS_DISPLAYED) {
                        errors.add(
                            String.format(SAVE_ERROR_RECORD_DETAIL, new String[] {currentId, err.getMessage()})
                        );            
                    }
                    errorCount++;
                }
            }
        }
        if (errorCount > MAX_ERRORS_DISPLAYED) {
            errors.add(
                String.format(SAVE_ERROR_TRUNC, new String[] {String.valueOf(errorCount - MAX_ERRORS_DISPLAYED)})
            );
        }
        return new SaveResponse(errors, saveResults.size() - errorCount);
    }

    public static Map<Id, List<SelectOption>> getFormCategoryOptionsByFormTypeId() {
        Map<Id, List<SelectOption>> returnMap = new Map<Id, List<SelectOption>>();
        List<Form_Category__mdt> categories = DomainUtils.getFormCategories();

        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('', Label.SELECT_OPTION_NONE));
        returnMap.put(NULL, options);        

        for (Form_Category__mdt category : categories) {
            if (returnMap.containsKey(category.Form_Type__c)) {
                returnMap.get(category.Form_Type__c).add(new SelectOption (category.Id, category.Label));
            } else {
                options = new List<SelectOption>();
                options.add(new SelectOption('', Label.SELECT_OPTION_NONE));
                options.add(new SelectOption(category.Id, category.Label));                    
                returnMap.put(category.Form_Type__c, options);
            }
        }
        return returnMap;
    }

    public static Map<Id, Form_Category__mdt> getFormCategoriesMap() {
        List<Form_Category__mdt> resultList = DomainUtils.getFormCategories();
        return new Map<Id, Form_Category__mdt>(resultList);
    }

    public static Form_Category__mdt getFormCategoryById(Id formCategoryId) {
        if (String.isBlank(formCategoryId)) {
            return new Form_Category__mdt();            
        }
        return DomainUtils.getFormCategoryById(formCategoryId)[0];
    }

    private static String getFormCategoryLabel(String form1099BoxId) {
        String formCategoryLabel;
        if (String.isNotEmpty(form1099BoxId)) {
            Form_Category__mdt formCategory = getFormCategoryById(form1099BoxId);
            formCategoryLabel = formCategory.Form_Type__r.Label + ' - ' + formCategory.Label;
        } 
        return formCategoryLabel;
    }

    private static SObject getSingleRecordValuesHelper(Id recordId, Schema.SObjectType objType, List<String> queryFields) {
        String queryCondition = 'Id = :recordId';   
        
        SOQLBuilder theQuery = new SOQLBuilder(objType);
        theQuery
            .assertIsAccessible()
            .selectFields(queryFields)
            .setCondition(queryCondition);
            
        return Database.query(theQuery.toSOQL())[0];            
    }
  
    public static Boolean validateFormTypeForDistributionDate(String formTypeId, Date distributionDate) {
        Boolean result = false;
        Integer disbursementYear = distributionDate.Year();
        if (!String.isEmpty(formTypeId)) {
            Form_Type__mdt formType = getFormTypeById(formTypeId);            
            Integer maxFormTypeYear = getMaxEffectiveYearForTypeAndYear(formType.Type__c, disbursementYear); 
            return maxFormTypeYear == (Integer)formType.Effective_Year__c;
        }
        return result;
    }

    public static Integer getMaxEffectiveYearForTypeAndYear(String formType, Integer effectiveYear) {
        List<Form_Type__mdt> resultList = DomainUtils.getMaxEffectiveDateForTypeAndYear(formType, effectiveYear);
        if (resultList.size() > 0) {
            return (Integer)resultList[0].Effective_Year__c;
        }
        return -1; 
    }

    private static Form_Type__mdt getFormTypeById(Id formTypeId) {
        return DomainUtils.getFormTypesById(formTypeId)[0];
    }    
}
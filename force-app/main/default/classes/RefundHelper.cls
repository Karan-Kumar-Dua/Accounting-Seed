public with sharing class RefundHelper extends AbstractLWCHelper {
    private static final String CREDIT_MEMO_OBJECT = GlobalVariables.PACKAGE_QUALIFIER + 'Billing__c';

    @AuraEnabled(Cacheable=true)
    public static Decimal nextCheckNumber(Id bankAccountId) {
        return CheckUtils.getNextCheckNumber(bankAccountId);
    }

    @AuraEnabled(Cacheable=true)
    public static FieldSetHandler.FieldSetResponse crRefundAdditionalFields(String sObjectName,String recordId) {
        FieldSetHandler.FieldSetRequest fsRequest = new FieldSetHandler.FieldSetRequest(
            GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Receipt__c',
            GlobalVariables.PACKAGE_QUALIFIER + 'CR_Refund',
            '',
            ''
        );    
        FieldSetHandler.FieldSetResponse response = FieldSetHelper.getColumns(JSON.serialize(fsRequest));
        if(sObjectName != CREDIT_MEMO_OBJECT){
            return getCashReceiptDataWithColumns(response,recordId);
        }
        return response;
    }
    private static FieldSetHandler.FieldSetResponse getCashReceiptDataWithColumns(FieldSetHandler.FieldSetResponse response, String recordId){
        Set<String> fields = new Set<String>();

        for(FieldSetHandler.FieldSetColumn col : response.mainColumns){
            fields.add(col.apiName);
        }

        Cash_Receipt__c cr = getCashReceipt(recordId,fields);

        if(cr != null){
            for(FieldSetHandler.FieldSetColumn col : response.mainColumns){
                col.value = String.valueOf(cr.get(col.apiName));
            }
        }
        return response;
    }
    private static Cash_Receipt__c getCashReceipt(String recordId, Set<String> fields){
        String queryCondition =  'Id = :recordId';

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .selectFields(new List<String>(fields))
            .setCondition(queryCondition);

        List<Cash_Receipt__c> result = Database.query(theQuery.toSOQL());

        if(!result.isEmpty() && result.size() > 0){
            return result[0];
        }
        return null;
    }
    @AuraEnabled(cacheable = true)
    public static String getObjectNameOfRecord(String recordId){
        try{
            Id passedRecordId = recordId;
            String objectName = passedRecordId.getSObjectType().getDescribe().getName();
            return objectName;
        } catch (Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * RefundData:
     *           [
     *              bankAccount=a0i0R000002gHYUQA2,
     *              memoTextArea=undefined,
     *              paymentTypeCombobox=Check,
     *              referenceTextArea=CR-00000 refund,
     *              refundAmountInput=200.0,
     *              refundDateInput=2022-03-14 00:00:00
     *          ]
     *
     * objectName: AcctSeed__Cash_Receipt__c
     * objectName: AcctSeed__Billing__c
     */
    @AuraEnabled
    public static SaveResponse createRefund(String values, String objectName, Id recordId, Map<String, Object> additionalParams){
        try{
            SaveResponse response;
            RefundHelper.RefundData refundDataObject = (RefundHelper.RefundData)JSON.deserialize(values, RefundHelper.RefundData.class);
            CreditsAndRefundsOptions crOptions = new CreditsAndRefundsOptions(recordId);
            crOptions.bankAccount = refundDataObject.bankAccount;
            crOptions.refundAmount = refundDataObject.refundAmountInput;
            crOptions.refundDate = refundDataObject.refundDateInput;
            crOptions.paymentType = refundDataObject.paymentTypeCombobox;
            crOptions.reference = refundDataObject.referenceTextArea;
            crOptions.memo = refundDataObject.memoTextArea;
            crOptions.additionalParams = additionalParams;
            if(objectName == CREDIT_MEMO_OBJECT){
                response = getResult(CreditsAndRefunds.createAndApplyRefundCashReceipt(crOptions));
            }
            else{
                String ledgerId = (String)crOptions?.additionalParams?.get(GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c');
                if (String.isBlank(ledgerId) || ledgerId == crOptions.ledger) {
                    response = getResult(CreditsAndRefunds.createRefundForCashReceipt(crOptions));
                } else {
                    response = new SaveResponse();
                    response.isSuccess = false;
                    response.errors.add(new ResponseError(new ServiceResult.Error(
                            String.format(
                                    Label.ERR_DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR,
                                    new List<String>{Label.COMMON_CASH_RECEIPT, Label.COMMON_REFUND_CASH_RECEIPT}
                            )
                    )));
                }
            }
            return response;
        } catch (Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static SaveResponse getResult(ServiceResult svcResult) {
        SaveResponse res = new SaveResponse(svcResult);
        
        if (res.isSuccess) {
            Id findId = svcResult.data;

            String q = new SOQLBuilder(Cash_Receipt__c.SObjectType)
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(new String[]{'Id', 'Name'})
                .setCondition('Id = :findId')
                .toSOQL();

            List<Cash_Receipt__c> records = (List<Cash_Receipt__c>) Database.query(q);

            if (!records.isEmpty()) {
                Cash_Receipt__c record = records[0];
                res.result.add(new ResponseResult(record.Id, record.Name));
            }
        }

        return res;
    }

    @TestVisible
    private class RefundData{
        @TestVisible
        Double refundAmountInput;
        @TestVisible
        Date refundDateInput;
        @TestVisible
        Id bankAccount;
        @TestVisible
        String paymentTypeCombobox;
        @TestVisible
        String referenceTextArea;
        @TestVisible
        String memoTextArea;
    }

}
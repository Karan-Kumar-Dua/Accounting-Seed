global abstract class AbstractBDCTransactionBulk {
    abstract global BDCServiceResult startTransactionProcess(List<GL_Account_Mapping__c> glams);

    public BDCServiceResult getAllTransactions(String bindingName){
        BDCServiceResult serviceResult = new BDCServiceResult();
        
        try{
            //Query GLAMs to use for AccountIds or Access Tokens
            List<GL_Account_Mapping__c> allGLAMs = DomainUtils.getGLAccountMappingsBySourceLastRefreshedDate(System.now(), bindingName); 

            startTransactionProcess(allGLAMs);
            serviceResult.isSuccess = true;
        } catch (Exception ex){
            throw new BDCService.BDCException(ex.getMessage());
        }

        return serviceResult;
    }

    global static void convertBDCTransactionToBankTransactions(List<BDCTransaction> transactions,  Map<String, BDCCategory> categoryById, String source){
        BankTransactionsHelper.processDownloadedBankTransactions(
            transactions,
            categoryById,
            source
        );
    }

    
    global static void updateGLAMS(List<BDCAccount> accountModels, List<BDCFinancialInstitutionIdentity> financialInstitutionIdentities){
        BankTransactionsHelper.updateGLAM(accountModels, financialInstitutionIdentities);
    }

    global static void publishTransactionsStartPlatformEvent(){
        EventPubSub.publish(
            EventPubSub.createEvent(
                EventPubSub.PublishDelay.IMMEDIATE,
                EventRegistry.RegisteredEvent.BANK_TRANSACTIONS_DOWNLOAD_START,
                FinancialSuiteUtils.getUUID(),
                null
            )
        );
    }

    global static void publishTransactionsFinishPlatformEvent(String eventMessage){
        EventPubSub.publish(
            EventPubSub.createEvent(
                EventPubSub.PublishDelay.IMMEDIATE,
                EventRegistry.RegisteredEvent.BANK_TRANSACTIONS_DOWNLOAD_END,
                FinancialSuiteUtils.getUUID(),
                eventMessage
            )
        );
    }


}
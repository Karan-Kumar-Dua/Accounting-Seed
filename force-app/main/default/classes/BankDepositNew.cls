public with sharing class BankDepositNew {

    public Bank_Deposit__c bankDeposit {get; set;}
    public Boolean showMessage {get; set;}  
    public Boolean isGLAccountError {get; set;}
    public Boolean isLedgerError {get; set;}
    public Boolean isDateError {get; set;}
    public Boolean IS_MULTI_CURRENCY_ENABLED {get; private set;}
    private List<SelectOption> glAccounts;

    public BankDepositNew(ApexPages.StandardController controller) {
        bankDeposit = (Bank_Deposit__c) controller.getRecord();
        IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;
        isGLAccountError = false;
        isDateError = false;   
        showMessage = false;
        bankDeposit.Ledger__c = LedgerHandler.getLedgerId();
        bankDeposit.Bank_Account__c =
            LedgerHandler.getInstanceWithoutSharing()
                .getLedgerById(LedgerHandler.getLedgerId())
                .Default_Bank_Account__c;
        bankDeposit.Deposit_Date__c = System.today();
    }

    public PageReference changeLedger() {
        bankDeposit.Bank_Account__c =
            LedgerHandler.getInstanceWithoutSharing()
                .getLedgerById(bankDeposit.Ledger__c)
                .Default_Bank_Account__c;
        return NULL;
    }
    
    public PageReference saveBankDeposit() {
        try {
            isDateError = false;
            isGLAccountError = false;
            isLedgerError = false;
            showMessage = false;

            if (bankDeposit.Ledger__c == null)
                isLedgerError = true;

            if (bankDeposit.Bank_Account__c == null)
                isGLAccountError = true;

            if (bankDeposit.Deposit_Date__c == null)
                isDateError = true;

            if (isLedgerError || isGLAccountError || isDateError)
                return null;

            SFDCSecurityUtils.insertCheckCRUDAndFLS(bankDeposit, new List<String>{
                'Bank_Account__c'
            });
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            showMessage = true;
            return NULL;
        }
        return new PageReference('/' + bankDeposit.Id);
    }
    
    public List<SelectOption> getGLAccounts() {
        if (glAccounts == NULL) {
            glAccounts = new List<SelectOption>();
            for (GL_Account__c glAccount : DomainUtils.getBankGlAccounts()) {
                glAccounts.add(new SelectOption(glAccount.Id, glAccount.Name));
            }
            if (glAccounts.isEmpty()) {
                glAccounts.add(new SelectOption('', '--' + Label.COMMON_NONE + '--'));
            }
        }
        return glAccounts;
    }

    public List<SelectOption> getAllLedgers() {
        List<SelectOption> ledgerOptions = new List<SelectOption>();
        for (SelectOption option : LedgerHandler.getInstanceWithSharing(true).getTransactionalLedgerSelectOptions()) {
            if (LedgerHandler.getInstanceWithSharing(true).isActiveLedger(option.getValue())) {
                ledgerOptions.add(option);
            }
        }
        return ledgerOptions;
    }

}
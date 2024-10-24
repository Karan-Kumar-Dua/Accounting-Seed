global with sharing class GLAccount {
    private static final String INVALID_GL_ACCOUNT_BALANCE_OPTION = Label.ERR_INVALID_GL_ACCOUNT_BALANCE_OPTION;
    private static APIServiceContext.APIServiceEntry serviceEntry = new APIServiceContext.APIServiceEntry();

    global class GLAccountException extends Exception{}

    global static List<GLAccountDefault> retrieveDefaults(Id ledgerId) {
        List<GLAccountDefault> result;
        try {
            ServiceResult validationResult = APIServiceContext.validateServiceContext(serviceEntry);

            if (validationResult.isSuccess) {
                result = GLAccountDefaultsHandler.instance.glAccountDefaultsByLedgerId(ledgerId);
            }
            else {
                throw new GLAccountException(String.join(validationResult.errors, ','));
            }
        } catch (Exception ex) {
            throw new GLAccountException(ex.getMessage());
        }

        return result != null ? result : new List<GLAccountDefault>();
    }

    public static List<ServiceResult> saveDefaults(List<GLAccountDefault> glAccountDefaults) {
        List<ServiceResult> result = new List<ServiceResult>();
        try {
            result = GLAccountDefaultsHandler.instance.saveGLAccountDefaults(glAccountDefaults);
            GLAccountDefaultsHandler.instance = null;

        } catch (Exception ex) {
            ServiceResult.Error[] errors = new List<ServiceResult.Error>();
            errors.add(new ServiceResult.Error(ex.getMessage()));
            result.add(new ServiceResult(null, false, errors));
        }
        return result;
    }

    public static ServiceResult retrieveBalance(GLAccountBalanceOption option) {
        ServiceResult result;
        try {
            ServiceResult.Error[] errors = validate(option);
            if (errors.isEmpty()) {
                GLAccountBalance balance = new GLAccountBalance(option);
                balance.calculate();
                result = new ServiceResult(null, true);
            }
            else {
                result = new ServiceResult(null, false, errors);
            }
        } catch (Exception ex) {
            ServiceResult.Error[] errors = new List<ServiceResult.Error>();
            errors.add(new ServiceResult.Error(ex.getMessage()));
            result = new ServiceResult(null, false, errors);
        }
        return result;
    }

    public static Map<String, GL_Account_Default__c> glAccountDefaultsMapByLedgerId(Id ledgerId) {
        return GLAccountDefaultsHandler.instance.glAccountDefaultsMapByLedgerIds.get(ledgerId) != null ?
        GLAccountDefaultsHandler.instance.glAccountDefaultsMapByLedgerIds.get(ledgerId) : new Map<String, GL_Account_Default__c>();
    }

    public static Map<Id, Map<String, GL_Account_Default__c>> glAccountDefaultsMapByLedgerId(Set<Id> ledgerIds) {
        Map<Id, Map<String, GL_Account_Default__c>> result = new Map<Id, Map<String, GL_Account_Default__c>>();
        for (Id ledgerId : ledgerIds) {
            if (GLAccountDefaultsHandler.instance.glAccountDefaultsMapByLedgerIds.get(ledgerId) != null) {
                result.put(ledgerId, GLAccountDefaultsHandler.instance.glAccountDefaultsMapByLedgerIds.get(ledgerId));
            }
        }
        return result;
    }

    public static List<ServiceResult> createGLAccountDefaultsByLedger(Set<Id> ledgerIds, Boolean onlyCashFlow) {
        GLAccountDefaultsHandler.instance.createOnlyCashFlow = onlyCashFlow;
        return createGLAccountDefaultsByLedger(ledgerIds);
    }

    public static List<ServiceResult> createGLAccountDefaultsByLedger(Set<Id> ledgerIds) {
        List<GLAccountDefault> glAccountDefaults = new List<GLAccountDefault>();
        for (Id ledgerId : ledgerIds) {
            glAccountDefaults.addAll(GLAccountDefaultsHandler.instance.createGLAccountDefaults(ledgerId));
        }
        return saveDefaults(glAccountDefaults);
    }

    private static ServiceResult.Error[] validate(GLAccountBalanceOption option) {
        ServiceResult.Error[] errors = new List<ServiceResult.Error>();
        if (option.inquiryDate == null) {
            errors.add(new ServiceResult.Error(
                String.format(INVALID_GL_ACCOUNT_BALANCE_OPTION, new String[] {'inquiryDate'})
            ));
        }
        if (String.isBlank(option.requestId)) {
            errors.add(new ServiceResult.Error(
                String.format(INVALID_GL_ACCOUNT_BALANCE_OPTION, new String[] {'requestId'})
            ));
        }
        if (!FinancialSuiteUtils.isValidId(option.ledgerId, Ledger__c.getSobjectType())) {
            errors.add(new ServiceResult.Error(
                String.format(INVALID_GL_ACCOUNT_BALANCE_OPTION, new String[] {'ledgerId'})
            ));
        }
        if (!FinancialSuiteUtils.isValidId(option.glAccountId, GL_Account__c.getSobjectType())) {
            errors.add(new ServiceResult.Error(
                String.format(INVALID_GL_ACCOUNT_BALANCE_OPTION, new String[] {'glAccountId'})
            ));
        }
        if (option.glVariable1Id != null 
                && !FinancialSuiteUtils.isValidId(option.glVariable1Id, Accounting_Variable__c.getSobjectType())) {
            errors.add(new ServiceResult.Error(
                String.format(INVALID_GL_ACCOUNT_BALANCE_OPTION, new String[] {'glVariable1Id'})
            ));
        }
        if (option.glVariable2Id != null 
                && !FinancialSuiteUtils.isValidId(option.glVariable2Id, Accounting_Variable__c.getSobjectType())) {
            errors.add(new ServiceResult.Error(
                String.format(INVALID_GL_ACCOUNT_BALANCE_OPTION, new String[] {'glVariable2Id'})
            ));
        }
        if (option.glVariable3Id != null 
                && !FinancialSuiteUtils.isValidId(option.glVariable3Id, Accounting_Variable__c.getSobjectType())) {
            errors.add(new ServiceResult.Error(
                String.format(INVALID_GL_ACCOUNT_BALANCE_OPTION, new String[] {'glVariable3Id'})
            ));
        }
        if (option.glVariable4Id != null 
                && !FinancialSuiteUtils.isValidId(option.glVariable4Id, Accounting_Variable__c.getSobjectType())) {
            errors.add(new ServiceResult.Error(
                String.format(INVALID_GL_ACCOUNT_BALANCE_OPTION, new String[] {'glVariable4Id'})
            ));
        }
        return errors;
    }

}
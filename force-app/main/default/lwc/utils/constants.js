import { LabelService } from './labelService';
export default class Constants {
    static GL_ACCOUNT_SPEC = {
        DEV_NAME: {
            CTA_GL_Account: 'CTA_GL_Account',
            Default_Debit_GL_Account_Revenue: 'Default_Debit_GL_Account_Revenue',
            Default_Credit_GL_Account_Revenue: 'Default_Credit_GL_Account_Revenue',
            Default_Debit_GL_Account_Expense: 'Default_Debit_GL_Account_Expense',
            Default_Credit_GL_Account_Expense: 'Default_Credit_GL_Account_Expense'
        }
    };
    static LEDGER = {
        TYPE_TRANSACTIONAL : LabelService.COMMON_TRANSACTIONAL,
        TYPE_BUDGET : LabelService.COMMON_BUDGET,
        TYPE_CONSOLIDATIONS_TRANSACTIONAL : LabelService.COMMON_CONSOLIDATIONS_TRANSACTIONAL,
        TYPE_CONSOLIDATIONS_BUDGET : LabelService.COMMON_CONSOLIDATIONS_BUDGET,
        TYPE_ELIMINATIONS_TRANSACTIONAL : LabelService.COMMON_ELIMINATIONS_TRANSACTIONAL,
        TYPE_ELIMINATIONS_BUDGET : LabelService.COMMON_ELIMINATIONS_BUDGET,
        ACCT_METHOD_ACCRUAL_CASH: LabelService.COMMON_ACCRUAL_CASH,
        ACCT_METHOD_ACCRUAL: LabelService.COMMON_ACCRUAL,
        ACCT_METHOD_CASH: LabelService.COMMON_CASH
    };
    static ACCT_PERIOD = {
        STATUS_OPEN_INTERIM : LabelService.COMMON_OPEN_IN_PROGRESS,
        STATUS_CLOSE_INTERIM : LabelService.COMMON_CLOSE_IN_PROGRESS,
        STATUS_OPEN : LabelService.COMMON_OPEN,
        STATUS_CLOSED : LabelService.COMMON_CLOSED,
        STATUS_ARCHIVED : LabelService.COMMON_ARCHIVED,
        STATUS_ARCHIVE_IN_PROGRESS : LabelService.COMMON_ARCHIVED_IN_PROGRESS
    };
    static ACCT_SETTINGS = {
        INVENTORY_VALIDATION_METHOD: {
            AVERAGE_COST: LabelService.COMMON_AVERAGE_COST,
            STANDARD_COST: LabelService.COMMON_STANDARD_COST
        }
    };
    static TAX_SETTINGS = {
        TAX_METHOD: {
            AVA_TAX: LabelService.COMMON_AVATAX,
            NATIVE_SALES_TAX: LabelService.TAX_OPTION_NATIVE
        }
    };
    static GL_ACCT = {
        TYPE_CASH_FLOW : LabelService.STD_REPORT_CASH_FLOW
    };
    static BILLING_FORMAT = {
        TYPE_BILLING: LabelService.COMMON_BILLING,
        TYPE_ACTIVITY_STATEMENT: LabelService.COMMON_ACTIVITY_STMT,
        TYPE_OUTSTANDING_STATEMENT: LabelService.INF_OUTSTANDING_STATEMENT,
        TYPE_PACKING_SLIP: LabelService.COMMON_PACKING_SLIP,
        TYPE_PURCHASE_ORDER: LabelService.COMMON_PURCHASE_ORDER
    };

    static CASE_OBJECT_KEY_PREFIX = '500';
}
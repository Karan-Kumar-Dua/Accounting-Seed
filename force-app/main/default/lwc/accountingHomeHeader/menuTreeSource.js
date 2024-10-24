import retrieveAHConfigurations from '@salesforce/apex/AccountingHomeHelper.retrieveAHConfigurations';
import { LabelService } from 'c/utils';

import OPPORTUNITY_OBJECT from '@salesforce/schema/Opportunity';
import BILLING_OBJECT from '@salesforce/schema/Billing__c';
import CASH_RECEIPT_OBJECT from '@salesforce/schema/Cash_Receipt__c';
import BANK_DEPOSIT_OBJECT from '@salesforce/schema/Bank_Deposit__c';

import ACCOUNT_PAYABLE_OBJECT from '@salesforce/schema/Account_Payable__c';
import CASH_DISBURSEMENT_OBJECT from '@salesforce/schema/Cash_Disbursement__c';
import CASH_DISBURSEMENT_BATCH_OBJECT from '@salesforce/schema/Cash_Disbursement_Batch__c';
import BANK_DISBURSEMENT_OBJECT from '@salesforce/schema/Bank_Disbursement__c';
import PAYMENT_PROPOSAL_OBJECT from '@salesforce/schema/Payment_Proposal__c';
import TIME_CARD_OBJECT from '@salesforce/schema/Time_Card__c';
import EXPENSE_REPORT_OBJECT from '@salesforce/schema/Expense_Report__c';

import BANK_RECONCILIATION2_OBJECT from '@salesforce/schema/Bank_Reconciliation2__c';

import JOURNAL_ENTRY_OBJECT from '@salesforce/schema/Journal_Entry__c';
import SCHEDULED_REVENUE_EXPENSE_OBJECT from '@salesforce/schema/Scheduled_Revenue_Expense__c';
import FIXED_ASSET_OBJECT from '@salesforce/schema/Fixed_Asset__c';
import FINANCIAL_CUBE_OBJECT from '@salesforce/schema/Financial_Cube__c';

// Run Reports -> Custom
import FINANCIAL_REPORT_DEFINITION_OBJECT from '@salesforce/schema/Financial_Report_Definition__c';
import GL_ACCOUNT_REPORTING_GROUP_OBJECT from '@salesforce/schema/GL_Account_Reporting_Group__c';

// Run Reports -> Utilities
import PAYMENT_ACTIVITY_OBJECT from '@salesforce/schema/Payment_Activity__c';
import EXCHANGE_RATE_OBJECT from '@salesforce/schema/Exchange_Rate__c';

// Ledger
import LEDGERS_OBJECT from '@salesforce/schema/Ledger__c';
import GL_ACCOUNT_OBJECT from '@salesforce/schema/GL_Account__c';
import ACCOUNTING_VARIABLE_OBJECT from '@salesforce/schema/Accounting_Variable__c';
import ACCOUNTING_PERIOD_OBJECT from '@salesforce/schema/Accounting_Period__c';
import PERIOD_TASK_OBJECT from '@salesforce/schema/Period_Task__c';

// Master
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import CONTACT_OBJECT from '@salesforce/schema/Contact';
import PRODUCT_OBJECT from '@salesforce/schema/Product2';
import PROJECT_OBJECT from '@salesforce/schema/Project__c';
import TIME_CARD_PERIOD_OBJECT from '@salesforce/schema/Time_Card_Period__c';
import COST_RATES_OBJECT from '@salesforce/schema/Cost_Rates__c';

// Automations
import RECURRING_BILLINGS_OBJECT from '@salesforce/schema/Recurring_Billing__c';
import RECURRING_PAYABLES_OBJECT from '@salesforce/schema/Recurring_Account_Payable__c';
import RECURRING_JOURNAL_ENTRY_OBJECT from '@salesforce/schema/Recurring_Journal_Entry__c';

// Configurations
import BILLING_FORMAT_OBJECT from '@salesforce/schema/Billing_Format__c';

// Utilities
import TAX_GROUP_OBJECT from '@salesforce/schema/Tax_Group__c';
import PAYMENT_PROCESSOR_OBJECT from '@salesforce/schema/Payment_Processor__c';
import TAX_SETTINGS_OBJECT from '@salesforce/schema/Tax_Settings__c';
import IMPORT_TEMPLATE_OBJECT from '@salesforce/schema/Import_Template__c';

const menuTreeSource = [
    {
        label: LabelService.accountingHomeCreateEntries,
        items: [
            {
                label: LabelService.accountingHomeRevenues,
                items: [
                    {
                        ...OPPORTUNITY_OBJECT
                    },
                    {
                        ...BILLING_OBJECT
                    },
                    {
                        ...CASH_RECEIPT_OBJECT
                    },
                    {
                        ...BANK_DEPOSIT_OBJECT
                    }
                ]
            },
            {
                label: LabelService.accountingHomeExpenses,
                items: [
                    {
                        ...ACCOUNT_PAYABLE_OBJECT
                    },
                    {
                        ...CASH_DISBURSEMENT_OBJECT
                    },
                    {
                        ...CASH_DISBURSEMENT_BATCH_OBJECT
                    },
                    {
                        ...BANK_DISBURSEMENT_OBJECT
                    },
                    {
                        ...PAYMENT_PROPOSAL_OBJECT
                    },
                    {
                        ...EXPENSE_REPORT_OBJECT
                    },
                    {
                        ...TIME_CARD_OBJECT
                    }
                ]
            },
            {
                label: LabelService.accountingHomeBanking,
                items: [
                    {
                        label: LabelService.accountingHomeBDC,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Bank_Direct_Connect2'
                    },
                    {
                        ...BANK_RECONCILIATION2_OBJECT
                    }
                ]
            },
            {
                label: LabelService.accountingHomeLedger,
                items: [
                    {
                        ...JOURNAL_ENTRY_OBJECT
                    },
                    {
                        ...SCHEDULED_REVENUE_EXPENSE_OBJECT
                    },
                    {
                        ...FIXED_ASSET_OBJECT
                    },
                    {
                        ...FINANCIAL_CUBE_OBJECT,
                        labelPattern: LabelService.accountingHomeBudgetEntries
                    },
                    {
                        label: LabelService.commonPayrollImport,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Payroll_File_Import'
                    }
                ]
            },
            {
                label: LabelService.accountingHomeOrders,
                items: [
                    {
                        label: LabelService.accountingHomeSalesOrders,
                        objectApiName: '{ERP_QUALIFIER}Sales_Order__c',
                        packages: [
                            'erp'
                        ],
                        error: LabelService.accountingHomeNoErpError
                    },
                    {
                        label: LabelService.accountingHomePurchaseOrders,
                        objectApiName: '{ERP_QUALIFIER}Purchase_Order__c',
                        packages: [
                            'erp'
                        ],
                        error: LabelService.accountingHomeNoErpError
                    },
                    {
                        label: LabelService.accountingHomeWorkOrders,
                        objectApiName: 'WorkOrder',
                        packages: [
                            'erp',
                            'fsl'
                        ],
                        error: LabelService.accountingHomeNoErpFslError
                    },
                    {
                        label: LabelService.accountingHomeInventoryQuantityAvailable,
                        objectApiName: '{ERP_QUALIFIER}Inventory_Balance__c',
                        packages: [
                            'erp'
                        ],
                        error: LabelService.accountingHomeNoErpError
                    },
                    {
                        label: LabelService.accountingHomeSerialNumSearch,
                        type: 'tab',
                        target: '{ERP_QUALIFIER}Serial_Number_Search',
                        packages: [
                            'erp'
                        ],
                        error: LabelService.accountingHomeNoErpError
                    }
                ]
            }
        ]
    },
    {
        label: LabelService.accountingHomeRunReports,
        items: [
            {
                label: LabelService.accountingHomeStandard,
                items: [
                    {
                        label: LabelService.stdReportProfitLoss,
                        type: 'lightningComponent',
                        target: '{PACKAGE_QUALIFIER}FinancialReporterNavProxy',
                        params: {
                            c__standardReport: 'profitLoss'
                        },
                        accessControlledByObject: FINANCIAL_REPORT_DEFINITION_OBJECT,
                        error: LabelService.errorNoAccessToFeature
                    },
                    {
                        label: LabelService.stdReportPLVsBudget,
                        type: 'lightningComponent',
                        target: '{PACKAGE_QUALIFIER}FinancialReporterNavProxy',
                        params: {
                            c__standardReport: 'profitLossVsBudget'
                        },
                        accessControlledByObject: FINANCIAL_REPORT_DEFINITION_OBJECT,
                        error: LabelService.errorNoAccessToFeature
                    },
                    {
                        label: LabelService.stdReportBalanceSheet,
                        type: 'lightningComponent',
                        target: '{PACKAGE_QUALIFIER}FinancialReporterNavProxy',
                        params: {
                            c__standardReport: 'balanceSheet'
                        },
                        accessControlledByObject: FINANCIAL_REPORT_DEFINITION_OBJECT,
                        error: LabelService.errorNoAccessToFeature
                    },
                    {
                        label: LabelService.stdReportTrialBalance,
                        type: 'lightningComponent',
                        target: '{PACKAGE_QUALIFIER}FinancialReporterNavProxy',
                        params: {
                            c__standardReport: 'trialBalance'
                        },
                        accessControlledByObject: FINANCIAL_REPORT_DEFINITION_OBJECT,
                        error: LabelService.errorNoAccessToFeature
                    },
                    {
                        label: LabelService.stdReportCashFlow,
                        type: 'lightningComponent',
                        target: '{PACKAGE_QUALIFIER}FinancialReporterNavProxy',
                        params: {
                            c__standardReport: 'cashFlow'
                        },
                        accessControlledByObject: FINANCIAL_REPORT_DEFINITION_OBJECT,
                        error: LabelService.errorNoAccessToFeature
                    },
                    {
                        label: LabelService.stdReportLedgerInquiry,
                        type: 'lightningComponent',
                        target: '{PACKAGE_QUALIFIER}FinancialReporterNavProxy',
                        params: {
                            c__standardReport: 'ledgerInquiry'
                        },
                        accessControlledByObject: FINANCIAL_REPORT_DEFINITION_OBJECT,
                        error: LabelService.errorNoAccessToFeature
                    }
                ]
            },
            {
                label: LabelService.accountingHomeCustom,
                items: [
                    {
                        label: LabelService.accountingHomeCustomReports,
                        type: 'lightningComponent',
                        target: '{PACKAGE_QUALIFIER}FinancialReporterNavProxy',
                        params: {
                            c__activeTab: 'customReports'
                        },
                        accessControlledByObject: FINANCIAL_REPORT_DEFINITION_OBJECT,
                        error: LabelService.errorNoAccessToFeature
                    },
                    {
                        ...FINANCIAL_REPORT_DEFINITION_OBJECT
                    },
                    {
                        ...GL_ACCOUNT_REPORTING_GROUP_OBJECT
                    },
                    {
                        label: LabelService.accountingHomeDashboards,
                        type: 'record',
                        postProcessor: (params) => {
                            params.self.type = params.self.target && params.self.type || 'object';
                            return {...params.self};
                        },
                        objectApiName: 'Dashboard',
                        target: '{ACCOUNTING_DASHBOARD}'
                    },
                    {
                        label: LabelService.accountingHomeManagementReports,
                        type: 'object',
                        objectApiName: 'Report'
                    }
                ]
            },
            {
                label: LabelService.accountingHomeConsolidations,
                items: [
                    {
                        label: LabelService.accountingHomeRunConsolidations,
                        type: 'lightningComponent',
                        target: '{PACKAGE_QUALIFIER}FinancialReporterNavProxy',
                        params: {
                            c__activeTab: 'runConsolidations'
                        },
                        accessControlledByObject: FINANCIAL_REPORT_DEFINITION_OBJECT,
                        error: LabelService.errorNoAccessToFeature
                    },
                    {
                        label: LabelService.accountingHomeSetupConsolidations,
                        type: 'lightningComponent',
                        target: '{PACKAGE_QUALIFIER}FinancialReporterNavProxy',
                        params: {
                            c__activeTab: 'setupConsolidations'
                        },
                        accessControlledByObject: FINANCIAL_REPORT_DEFINITION_OBJECT,
                        error: LabelService.errorNoAccessToFeature
                    }
                ]
            },
            {
                label: LabelService.commonUtilities,
                items: [
                    {
                        label: LabelService.accountingHomeReportSettings,
                        type: 'lightningComponent',
                        target: '{PACKAGE_QUALIFIER}FinancialReporterNavProxy',
                        params: {
                            c__activeTab: 'reportSettings'
                        },
                        accessControlledByObject: FINANCIAL_REPORT_DEFINITION_OBJECT,
                        error: LabelService.errorNoAccessToFeature
                    },
                    {
                        label: LabelService.accountingHomeTaxExceptionReport,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Tax_Exception_Report',
                        error: LabelService.accountingHomeNoAvaTax
                    },
                    {
                        ...PAYMENT_ACTIVITY_OBJECT
                    },
                    {
                        ...EXCHANGE_RATE_OBJECT
                    }
                ]
            }
        ]
    },
    {
        label: LabelService.accountingHomeSetup,
        items: [
            {
                label: LabelService.accountingHomeLedger,
                items: [
                    {
                        ...LEDGERS_OBJECT
                    },
                    {
                        ...GL_ACCOUNT_OBJECT
                    },
                    {
                        ...ACCOUNTING_VARIABLE_OBJECT
                    },
                    {
                        ...ACCOUNTING_PERIOD_OBJECT
                    },
                    {
                        ...PERIOD_TASK_OBJECT
                    }
                ]
            },
            {
                label: LabelService.accountingHomeMaster,
                items: [
                    {
                        ...ACCOUNT_OBJECT
                    },
                    {
                        ...CONTACT_OBJECT
                    },
                    {
                        ...PRODUCT_OBJECT
                    },
                    {
                        label: LabelService.accountingHomeProductPrices,
                        objectApiName: '{ERP_QUALIFIER}Purchase_Price__c',
                        packages: [
                            'erp'
                        ],
                        error: LabelService.accountingHomeNoErpError
                    },
                    {
                        label: LabelService.accountingHomeWarehouses,
                        objectApiName: '{ERP_QUALIFIER}Warehouse__c',
                        packages: [
                            'erp'
                        ],
                        error: LabelService.accountingHomeNoErpError
                    },
                    {
                        ...PROJECT_OBJECT
                    },
                    {
                        ...TIME_CARD_PERIOD_OBJECT
                    },
                    {
                        ...COST_RATES_OBJECT
                    }
                ]
            },
            {
                label: LabelService.commonAutomations,
                items: [
                    {
                        ...RECURRING_BILLINGS_OBJECT
                    },
                    {
                        ...RECURRING_PAYABLES_OBJECT
                    },
                    {
                        ...RECURRING_JOURNAL_ENTRY_OBJECT
                    },
                    {
                        label: LabelService.automatedJobsPageHeader,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Automated_Jobs'
                    },
                    {
                        label: LabelService.postSettingsTitle,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Post_Settings'
                    }
                ]
            },
            {
                label: LabelService.commonConfiguration,
                items: [
                    {
                        label: LabelService.defaultLedgerTitle,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Default_Ledger'
                    },
                    {
                        label: LabelService.defaultGlAccountsTitle,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Default_GL_Accounts'
                    },
                    {
                        label: LabelService.multiLedgerDefaultsTitle,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Multi_Ledger_Defaults'
                    },
                    {
                        ...BILLING_FORMAT_OBJECT
                    },
                    {
                        label: LabelService.checkPrintAdjustmentsTitle,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Check_Print_Adjustments'
                    },
                    {
                        label: LabelService.enablementsTitle,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Enablements'
                    },
                ]
            },
            {
                label: LabelService.commonUtilities,
                items: [
                    {
                        ...TAX_GROUP_OBJECT
                    },
                    {
                        ...TAX_SETTINGS_OBJECT
                    },
                    {
                        label: LabelService.vatReportingSettings,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}VAT_Reporting_Settings'
                    },
                    {
                        ...PAYMENT_PROCESSOR_OBJECT
                    },
                    {
                        label: LabelService.paymentSettings,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Stripe_Settings'
                    },
                    {
                        label: LabelService.purgeDataSectionHeader,
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Purge_Data'
                    },
                    {
                        ...IMPORT_TEMPLATE_OBJECT
                    },
                    {
                        label: LabelService.ACCOUNTING_SEED_HUB, 
                        type: 'tab',
                        target: '{PACKAGE_QUALIFIER}Accounting_Seed_Hub'
                    }
                ]
            }
        ]
    }
];

class MenuTreeHelper {
    static fetchAHConfigurations() {
        return retrieveAHConfigurations({
            sobjectApiNames: [
                OPPORTUNITY_OBJECT, BILLING_OBJECT, CASH_RECEIPT_OBJECT, BANK_DEPOSIT_OBJECT, ACCOUNT_PAYABLE_OBJECT,
                CASH_DISBURSEMENT_OBJECT, CASH_DISBURSEMENT_BATCH_OBJECT, BANK_DISBURSEMENT_OBJECT, TIME_CARD_OBJECT, EXPENSE_REPORT_OBJECT,
                BANK_RECONCILIATION2_OBJECT, JOURNAL_ENTRY_OBJECT, SCHEDULED_REVENUE_EXPENSE_OBJECT, FIXED_ASSET_OBJECT, FINANCIAL_CUBE_OBJECT,
                LEDGERS_OBJECT, GL_ACCOUNT_OBJECT, ACCOUNTING_PERIOD_OBJECT, ACCOUNTING_VARIABLE_OBJECT, PERIOD_TASK_OBJECT,
                ACCOUNT_OBJECT, CONTACT_OBJECT, PRODUCT_OBJECT, PROJECT_OBJECT, TIME_CARD_PERIOD_OBJECT, COST_RATES_OBJECT,
                RECURRING_BILLINGS_OBJECT, RECURRING_PAYABLES_OBJECT, RECURRING_JOURNAL_ENTRY_OBJECT,
                BILLING_FORMAT_OBJECT, TAX_GROUP_OBJECT, TAX_SETTINGS_OBJECT, PAYMENT_PROCESSOR_OBJECT,
                FINANCIAL_REPORT_DEFINITION_OBJECT, GL_ACCOUNT_REPORTING_GROUP_OBJECT, PAYMENT_ACTIVITY_OBJECT,
                EXCHANGE_RATE_OBJECT,IMPORT_TEMPLATE_OBJECT,PAYMENT_PROPOSAL_OBJECT
            ].map(item => item.objectApiName)
        });
    }
}


export {MenuTreeHelper, menuTreeSource};
import { LightningElement, wire } from 'lwc';
import { LabelService, NotificationService, KnowledgeBase } from 'c/utils';
import getConfigs from '@salesforce/apex/AccountingSettingsHelper.getConfigs';
import purgeAPAgingHistory from '@salesforce/apex/PurgeDataHelper.purgeAPAgingHistory';
import purgeBillingAgingHistory from '@salesforce/apex/PurgeDataHelper.purgeBillingAgingHistory';
import purgeFinancialReportResults from '@salesforce/apex/PurgeDataHelper.purgeFinancialReportResults';
import purgeZeroBalanceFinancialCubes from '@salesforce/apex/PurgeDataHelper.purgeZeroBalanceFinancialCubes';
import purgeSourceDocumentsInInterimPostingStatus from '@salesforce/apex/PurgeDataHelper.purgeSourceDocumentsInInterimPostingStatus';
import purgeAutomatedJobResults from '@salesforce/apex/PurgeDataHelper.purgeAutomatedJobResults';
import purgeInventoryBalanceHistory from '@salesforce/apex/PurgeDataHelper.purgeInventoryBalanceHistory';
import ACCOUNTING_PERIOD_OBJECT from '@salesforce/schema/Accounting_Period__c';
import HAS_READ_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Read_Access';
import HAS_EDIT_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Write_Access';
import Labels from './labels';

/**
 * Accounting settings purge data component surfaced in a lightning
 * tab and responsible for triggering data deletion jobs in the
 * PurgeDataHelper class.
 */
export default class PurgeData extends LightningElement {
    /**
     * Expose labels to the UI
     */
    labels = {...Labels, ...LabelService};

    @wire (getConfigs)
    configs;

    /**
     * Used for searching with the lookup component
     */
    accountingPeriodApiName = ACCOUNTING_PERIOD_OBJECT.objectApiName;

    /**
     * Header navigation
     */
    breadcrumbs = [
        { title: LabelService.commonAccountingHome, tab: 'AcctSeed__Accounting_Home2' },
        { title: LabelService.accountingSetup }
    ];

    /**
     * Knowledge base links on the right side
     * of the header
     */
    knowledgeBase = [
        {
            url: KnowledgeBase.purgeData,
            iconName: 'standard:question_feed',
            iconAltText: LabelService.commonKnowledgeBase
        }
    ];

    /**
     * Default value for purge automated job results datepicker
     */
    today = new Date().toISOString().split('T')[0];

    /**
     * Permission checks for UI elements
     */
    get userCanView() {
        // write gives implicit read permission
        return HAS_READ_PERMISSION || HAS_EDIT_PERMISSION;
    }

    get userCanEdit () {
        return HAS_EDIT_PERMISSION;
    }

    get userCannotEdit () {
        return !HAS_EDIT_PERMISSION;
    }

    get ldvEnabled () {
        return this.configs?.data?.enablements?.largeDataVolumeModeEnabled;
    }

    get erpEnabled () {
        return this.configs?.data?.pkgs?.erp?.installed;
    }

    /**
     * Purge AP Aging History
     */
    handlePurgeAPAgingHistory () {
        const field = this.template
            .querySelector('[data-id="lookup-apAgingHistory"]');

        const button = this.template
            .querySelector('[data-id="lightningButton-purgeAPAgingHistory"]');

        const valid = field.getSelection().length > 0;

        if (valid) {
            button.disabled = true;
            field.errors = []; // clear validity

            purgeAPAgingHistory({
                period: field.getSelection()[0].id
            })
            .then((res) => {
                NotificationService.displayToastMessage(
                    this,
                    res,
                    LabelService.commonSuccess,
                    'success'
                );
            })
            .catch((err) => {
                console.error(err);
            })
            .finally(() => {
                button.disabled = false;
            });
        } else {
            // set the error after validation, not on blur
            field.setCustomValidity(LabelService.errorValueMissing);
        }
    }

    /**
     * Purge Billing Aging History
     */
    handlePurgeBillingAgingHistory () {
        const field = this.template
            .querySelector('[data-id="lookup-billingAgingHistory"]');
        
        const button = this.template
            .querySelector('[data-id="lightningButton-purgeBillingAgingHistory"]');

        
        const valid = field.getSelection().length > 0;

        if (valid) {
            button.disabled = true;
            field.errors = []; // clear validity

            purgeBillingAgingHistory({
                period: field.getSelection()[0].id
            })
            .then((res) => {
                NotificationService.displayToastMessage(
                    this,
                    res,
                    LabelService.commonSuccess,
                    'success'
                );
            })
            .catch((err) => {
                console.error(err);
            })
            .finally(() => {
                button.disabled = false;
            });
        } else {
            // set the error after validation, not on blur
            field.setCustomValidity(LabelService.errorValueMissing);
        }
    }

    /**
     * Purge Financial Report Results
     */
    handlePurgeFinancialReportResults () {
        const button = this.template
            .querySelector('[data-id="lightningButton-purgeFinancialReportResults"]');

        button.disabled = true;

        purgeFinancialReportResults()
        .then((res) => {
            NotificationService.displayToastMessage(
                this,
                res,
                LabelService.commonSuccess,
                'success'
            );
        })
        .catch((err) => {
            console.error(err);
        })
        .finally(() => {
            button.disabled = false;
        });
    }

    /**
     * Purge Zero Balance Financial Cubes
     */
    handlePurgeZeroBalanceFinancialCubes () {
        const button = this.template
            .querySelector('[data-id="lightningButton-purgeZeroBalanceFinancialCubes"]');

        button.disabled = true;

        purgeZeroBalanceFinancialCubes()
        .then((res) => {
            NotificationService.displayToastMessage(
                this,
                res,
                LabelService.commonSuccess,
                'success'
            );
        })
        .catch((err) => {
            console.error(err);
        })
        .finally(() => {
            button.disabled = false;
        });
    }

    /**
     * Purge Source Documents stuck in interim Posting Status
     */
    handlePurgeSourceDocumentsInInterimPostingStatus () {
        const button = this.template
            .querySelector('[data-id="lightningButton-purgeSourceDocumentsInInterimPostingStatus"]');

        button.disabled = true;

        purgeSourceDocumentsInInterimPostingStatus()
            .then((res) => {
                NotificationService.displayToastMessage(
                    this,
                    res,
                    LabelService.commonSuccess,
                    'success'
                );
            })
            .catch((err) => {
                console.error(err);
            })
            .finally(() => {
                button.disabled = false;
            });
    }

    /**
     * Purge Automated Job Results
     */
    handlePurgeAutomatedJobResults () {
        const field = this.template
            .querySelector('[data-id="lightningInput-beforeDate"]');

        const button = this.template
            .querySelector('[data-id="lightningButton-purgeAutomatedJobResults"]');
        
        const valid = field.reportValidity();

        if (valid) {
            button.disabled = true;

            purgeAutomatedJobResults({
                before: field.value
            })
            .then((res) => {
                NotificationService.displayToastMessage(
                    this,
                    res,
                    LabelService.commonSuccess,
                    'success'
                );
            })
            .catch((err) => {
                console.error(err);
            })
            .finally(() => {
                button.disabled = false;
            });
        } else {
            // set the error after validation, not on blur
            field.setCustomValidity(LabelService.errorValueMissing);
        }
    }

     /**
     * Purge ERP Inventory Balance History
     */
      handlePurgeInventoryBalanceHistory () {
        const field = this.template
            .querySelector('[data-id="lightningInput-purgeInventoryBalanceHistory"]');

        const button = this.template
            .querySelector('[data-id="lightningButton-purgeInventoryBalanceHistory"]');
        
        const valid = field.reportValidity();

        if (valid) {
            button.disabled = true;

            purgeInventoryBalanceHistory({
                before: field.value
            })
            .then((res) => {
                NotificationService.displayToastMessage(
                    this,
                    res,
                    LabelService.commonSuccess,
                    'success'
                );
            })
            .catch((err) => {
                console.error(err);
                NotificationService.displayToastMessage(
                    this,
                    err.body.message,
                    LabelService.commonSuccess,
                    'error'
                );
            })
            .finally(() => {
                button.disabled = false;
            });
        } else {
            // set the error after validation, not on blur
            field.setCustomValidity(LabelService.errorValueMissing);
        }
    }

}
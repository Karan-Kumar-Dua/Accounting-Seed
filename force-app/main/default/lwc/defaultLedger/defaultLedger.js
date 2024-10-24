import { LightningElement, wire, track } from 'lwc';
import { LabelService, NotificationService, RecordProxy, KnowledgeBase, CommonUtils } from 'c/utils';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { refreshApex } from '@salesforce/apex';
import getSettings from '@salesforce/apex/AccountingSettingsHelper.getSettings';
import saveSettings from '@salesforce/apex/AccountingSettingsHelper.save';
import getLedgers from '@salesforce/apex/AccountingSettingsHelper.getLedgers';
import ACCOUNTING_SETTINGS_OBJECT from '@salesforce/schema/Accounting_Settings__c';
import HAS_READ_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Read_Access';
import HAS_EDIT_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Write_Access';
import LEDGER_OBJECT from '@salesforce/schema/Ledger__c';
import LEDGER_NAME_FIELD from '@salesforce/schema/Ledger__c.Name';
import LEDGER_TYPE_FIELD from '@salesforce/schema/Ledger__c.Type__c';

export default class DefaultLedger extends LightningElement {
    /**
     * Expose labels to the UI
     */
    labels = LabelService;

    /**
     * Quick access to field labels instead of storing
     * these as custom labels.
     */
     @wire (getObjectInfo, { objectApiName: ACCOUNTING_SETTINGS_OBJECT })
     getAccountingSettingsInfo({ err, data}) {
         if (err) {
             console.error(err);
         }
         if (data) {
             this.accountingSettingsInfo = new RecordProxy(data);
             this.prepareAccountingSettings();
         }
     }
 
     @wire (getSettings)
     getAccountingSettings (result) {
         this.rawAccountingSettings = result;
         if (this.rawAccountingSettings.data) {
             this.prepareAccountingSettings();
         }
         if (this.rawAccountingSettings.error) {
             console.error(this.rawAccountingSettings.error);
         }
     }

    /**
     * Combobox options
     */
    @wire (getLedgers)
    ledgers;

    @track
    accountingSettingsInfo;

    @track
    accountingSettings;

    rawAccountingSettings;

    showSpinner = true;

    /**
     * Page header navigation
     */
    get breadcrumbs () {
        return [
            { title: LabelService.commonAccountingHome,
                tab: `${this.accountingSettingsInfo?.namespace || CommonUtils.getPackageQualifier(LEDGER_OBJECT.objectApiName)}Accounting_Home2`},
            { title: LabelService.accountingSetup }
        ];
    }

    /**
     * Edit mode on/off
     */
    isEditable = false;

    ledgerFields = [
        LEDGER_NAME_FIELD,
        LEDGER_TYPE_FIELD
    ];

    /**
     * Right side header icons that link to KB
     */
    knowledgeBase = [
        { 
            iconName: 'standard:question_feed', 
            iconAltText: LabelService.knowledgeBase,
            url: KnowledgeBase.defaultLedger
        }
    ];
 
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

    /**
     * Disable input fields when in read mode.
     */
    get isDisabled () {
        return !this.isEditable || !HAS_EDIT_PERMISSION;
    }

    /**
     * Page has all its necessary data
     */
    get isLoaded () {
        return this.accountingSettings && 
            this.accountingSettingsInfo &&
            this.ledgers.data;
    }

    get ledgerObjectApiName () {
        return LEDGER_OBJECT.objectApiName;
    }

    /**
     * Enables edit mode for the auto-post settings section.
     */
    handleEdit () {
        this.isEditable = true;
    }

    /**
     * Discard changes to auto-post settings.
     */
    handleCancel () {
        this.isEditable = false;
        let fields = [...this.template.querySelectorAll('[data-field]')];
        fields.forEach((field) => {
            field.value = this.accountingSettings[field.dataset.field];
        });
    }

    /**
     * Save auto-post settings.
     */
    handleSave () {
        this.showSpinner = true;
        let settings = { ...this.accountingSettings };
        let fields = [...this.template.querySelectorAll('[data-field]')];
        fields.forEach((field) => {
            settings[field.dataset.field] = field.value;
        });

        settings = this.accountingSettingsInfo.getSObject(settings);

        saveSettings({
            settings: settings
        }).then((res) => {
            this.isEditable = false;

            NotificationService.displayToastMessage(
                this,
                LabelService.commonSaveSuccess,
                LabelService.commonSuccess,
                'success'
            );
        }).catch((err) => {
            NotificationService.displayToastMessage(
                this,
                err.body.message,
                `${LabelService.commonToastErrorTitle}:`,
                'error'
            );
        }).finally(() => {
            this.showSpinner = false;
            refreshApex(this.rawAccountingSettings);
        });
    }

    prepareAccountingSettings() {
        this.showSpinner = false
        if (this.accountingSettingsInfo && this.rawAccountingSettings.data) {
            this.accountingSettings = this.accountingSettingsInfo.getRecord(this.rawAccountingSettings.data);
        }
    }

}
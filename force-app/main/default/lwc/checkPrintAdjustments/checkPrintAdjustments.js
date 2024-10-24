import { LightningElement, wire, track} from 'lwc';
import { LabelService, NotificationService, RecordProxy, KnowledgeBase, CommonUtils } from 'c/utils';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { refreshApex } from '@salesforce/apex';
import getSettings from '@salesforce/apex/AccountingSettingsHelper.getSettings';
import saveSettings from '@salesforce/apex/AccountingSettingsHelper.save';
import ACCOUNTING_SETTINGS_OBJECT from '@salesforce/schema/Accounting_Settings__c';
import HAS_READ_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Read_Access';
import HAS_EDIT_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Write_Access';

export default class CheckPrintAdjustments extends LightningElement {

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
         }
     }
     
     @wire (getSettings)
     getAccountingSettings ({ err, data}) {
         if (err) {
             console.error(err);
         }
         if (data && (HAS_READ_PERMISSION || HAS_EDIT_PERMISSION)) {
             this.accountingSettings = this.accountingSettingsInfo?.getRecord(data);
         }
     }

    /**
     * Page header navigation
     */
     get breadcrumbs () {
        return [
            { title: LabelService.commonAccountingHome,
                tab: `${this.accountingSettingsInfo?.namespace || CommonUtils.getPackageQualifier(ACCOUNTING_SETTINGS_OBJECT.objectApiName)}Accounting_Home2`},
            { title: LabelService.accountingSetup }
        ];
    }

    @track
    accountingSettings;

    @track
    accountingSettingsInfo;

    /**
     * Edit mode on/off
     */
    isEditable = false;

    /**
     * Right side header icons that link to KB
     */
    knowledgeBase = [
        { 
            iconName: 'standard:question_feed', 
            iconAltText: LabelService.knowledgeBase,
            url: KnowledgeBase.checkPrintAdjustments
        }
    ];
    
    /**
     * Expose labels to the UI
     */
    labels = LabelService;
 
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
        return this.accountingSettings && this.accountingSettingsInfo;
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
            field.checked = this.accountingSettings[field.dataset.field];
        });
    }

    /**
     * Save auto-post settings.
     */
    handleSave() {
        if (!this.validateInputs()) {
            return;
        }
        this.isEditable = false;
        const settings = { ...this.accountingSettings };
        let fields = [...this.template.querySelectorAll('[data-field]')];
        fields.forEach((field) => {
            settings[field.dataset.field] = field.value;
        });

        // Re-namespace
        const nsSettings = this.accountingSettingsInfo.getSObject(settings);

        saveSettings({
            settings: nsSettings
        }).then((res) => {
            NotificationService.displayToastMessage(
                this,
                LabelService.commonSaveSuccess,
                LabelService.commonSuccess,
                'success'
            );
            this.accountingSettings = settings;
        }).catch((err) => {
            NotificationService.displayToastMessage(
                this,
                err.body.message,
                LabelService.commonToastErrorTitle,
                'error'
            );
        });
    }
    validateInputs() {
        const isValid = [...this.template.querySelectorAll('[data-field]')]
            .reduce((validSoFar, inputCmp) => {
                if (inputCmp.value !== '' && !(/^-?\d+$/.test(inputCmp.value))){
                    inputCmp.setCustomValidity(this.labels.enterValidWholeNumber);
                } else {
                    inputCmp.setCustomValidity('');
                }
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
        }, true);
        return isValid;
    }
    
}
import { LightningElement, track, wire } from 'lwc';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { keywords } from "c/lookupKeywords";
import { Ledger, FinancialReporterSettings } from "c/sobject";
import getSettings from "@salesforce/apex/FinancialReporterSettingsHelper.getSettings";
import saveSetting from "@salesforce/apex/FinancialReporterSettingsHelper.saveSettings";
import getContentVersionInfo from "@salesforce/apex/FinancialReporterSettingsHelper.getContentVersionInfo";
import { CommonUtils, NotificationService, Constants, LabelService } from "c/utils";
import Labels from './labels';

const DUPLICATE_ACCOUNTING_PERIOD_MSG = Labels.INF_DUPLICATE_ACCOUNTING_PERIOD_MSG;
const DUPLICATE_NAME_LOGO_MSG = Labels.INF_DUPLICATE_NAME_LOGO_MSG;
const EXPAND_REPORT_ROWS_MSG = Labels.INF_EXPAND_REPORT_ROWS_MSG;
const SETTING_SAVED_SUCCESSFULLY_MSG = LabelService.commonChangesSaved;
const SETTING_SAVED_SUCCESSFULLY_TITLE = LabelService.commonSaveSuccess;
const ROUNDING_HELP = Labels.INF_ROUNDING_HELP;
const DUPLICATE_LEDGERS_POPUP_TITLE = Labels.INF_DUPLICATE_ON_ALL_LEDGERS + '?';


export default class FinReporterSettings extends LightningElement {

    labels = {...LabelService, ...Labels};
    ledger = Ledger;
    financialReporterSettings = FinancialReporterSettings;
    frs = new FinancialReporterSettings();
    transactionLedgerLookupFilter = {
        type: keywords.type.STRING,
        field: Ledger.type1.fieldApiName,
        op: keywords.op.IN,
        val: [Constants.LEDGER.TYPE_TRANSACTIONAL, Constants.LEDGER.TYPE_CONSOLIDATIONS_TRANSACTIONAL, Constants.LEDGER.TYPE_ELIMINATIONS_TRANSACTIONAL]
    };
    showDuplicateConfirmation = false;
    duplicateConfirmationMessage;
    duplicateNameAndLogo = false;
    duplicateColumnHeaders = false;
    duplicateExpandReportRows = false;
    ledgerErrors = [];
    error;
    isError = false;
    read = true;
    isLedgerSpinner = true;
    isSpinner = true;
    originalSettingsDTO;
    @track
    settingsDTO;
    @track
    isEditAllowed = false;
    roundingHelpText = ROUNDING_HELP;

    toggleRead = () => this.read = !this.read;


    @wire(getObjectInfo, { objectApiName: FinancialReporterSettings.objectApiName })
    finReporterSettingsObjectInfo({data}) {
        if (data) {
            this.isEditAllowed = data.updateable;
        }
    }

    get logoUrl() {
        let url = '';
        if (this.settingsDTO && this.settingsDTO.companyLogoId) {
            url = '/sfc/servlet.shepherd/version/download/'  + this.settingsDTO.companyLogoId;
        }
        return url;
    }

    get logoFileName() {
        let fileName = 'No Logo'
        if (this.settingsDTO && this.settingsDTO.companyLogoFileName) {
            fileName = this.settingsDTO.companyLogoFileName;
        }
        return fileName;
    }

    get acceptedFormats() {
        return ['.png', '.jpg', '.jpeg', '.gif'];
    }

    get companyName() {
        if (this.settingsDTO) {
            return CommonUtils.getDataValue(
                this.frs.company_name, this.settingsDTO.settings
            );
        }
    }

    get selectedColumnHeaderVariantValue() {
        if (this.settingsDTO) {
            return CommonUtils.getDataValue(
                this.frs.column_header_variant, this.settingsDTO.settings
            );
        }
    }

    get selectedColumnHeaderVariantLabel() {
        if (this.settingsDTO) {
            let selectedPicklistValue = CommonUtils.getDataValue(
                this.frs.column_header_variant, this.settingsDTO.settings
            );
            let option = this.settingsDTO.columnHeaderVariantOptions.find(picklistOption => {
                return picklistOption.value === selectedPicklistValue;
            });
            return option.label;
        }
    }

    get selectedRoundingLabel() {
        if (this.settingsDTO) {
            return CommonUtils.getDataValue(
                this.frs.rounding, this.settingsDTO.settings
            );
        }
    }

    get ledgerId() {
        if (this.settingsDTO) {
            return this.settingsDTO.ledgerId;
        }
    }

    get selectedExpandReportRowsValue() {
        if (this.settingsDTO) {
            return CommonUtils.getDataValue(
              this.frs.expand_report_rows, this.settingsDTO.settings
            );
        }
    }

    setCurrentLedgerId(event) {
        this.settingsDTO.ledgerId = event.detail && event.detail.recordId;
        if (this.settingsDTO.ledgerId) {
            this.ledgerErrors = [];
            this.receiveSettings(this.settingsDTO.ledgerId);
        }
    }

    setCompanyName(event) {
        CommonUtils.setDataValue(this.frs.company_name, this.settingsDTO.settings, event.detail.value);
    }

    setColumnHeaderVariant(event) {
        CommonUtils.setDataValue(this.frs.column_header_variant, this.settingsDTO.settings, event.detail.value);
    }

    setRounding(event) {
        let roundingValue = (event.detail.value) ? event.detail.value : 'No Rounding';
        CommonUtils.setDataValue(this.frs.rounding, this.settingsDTO.settings, roundingValue);
    }

    setExpandReportRows(event) {
        CommonUtils.setDataValue(this.frs.expand_report_rows, this.settingsDTO.settings, event.detail.checked);
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        let contentDocumentId = uploadedFiles[0].documentId;
        this.populateLogoFileInfo(contentDocumentId);
    }

    handleEdit() {
        this.toggleRead();
    }

    handleCancel() {
        this.uncheckDuplicateNameAndLogo();
        this.uncheckDuplicateColumnHeaders();
        this.originalSettingsDTO.companyLogoId = this.settingsDTO.companyLogoId;
        this.originalSettingsDTO.companyLogoFileName = this.settingsDTO.companyLogoFileName;
        this.settingsDTO = CommonUtils.copyObject(this.originalSettingsDTO);
        this.toggleRead();
    }

    handleSave() {
        if (this.settingsDTO.ledgerId && this.ledgerErrors.length === 0) {
            this.isSpinner = true;
            this.isError = false;
            saveSetting({
                serializedFRS: JSON.stringify(this.settingsDTO),
                transmitNameAndLogoToAll: this.duplicateNameAndLogo,
                transmitColumnHeaderToAll: this.duplicateColumnHeaders,
                transmitExpandReportRowsToAll: this.duplicateExpandReportRows
            }).then((result) => {
                NotificationService.displayToastMessage(
                    this,
                    SETTING_SAVED_SUCCESSFULLY_MSG,
                    SETTING_SAVED_SUCCESSFULLY_TITLE
                );
                this.originalSettingsDTO = result;
                this.settingsDTO = CommonUtils.copyObject(this.originalSettingsDTO);
                this.handleRefreshCachedSettings(this.settingsDTO.settings.Id);
                this.toggleRead();
                this.uncheckDuplicateNameAndLogo();
                this.uncheckDuplicateColumnHeaders();
                this.uncheckDuplicateExpandReportRows();
                this.isSpinner = false;
            }).catch(error => {
                this.error = error;
                this.isError = true;
                this.isSpinner = false;
            });
        }
        else {
            this.ledgerErrors = [{message: Labels.ERR_VALUE_REQ_SAVE_SETTINGS}];
        }
    }

    handleRefreshCachedSettings(settingsId) {
        try {
            getRecordNotifyChange([{recordId: settingsId}]);
        }
        catch(error) {}
    }

    handleDuplicationCancel() {
        switch (this.duplicateConfirmationMessage) {
            case DUPLICATE_ACCOUNTING_PERIOD_MSG:
                this.uncheckDuplicateColumnHeaders();
                break;
            case DUPLICATE_NAME_LOGO_MSG:
                this.uncheckDuplicateNameAndLogo();
                break;
            case EXPAND_REPORT_ROWS_MSG:
                this.uncheckDuplicateExpandReportRows();
                break;
            default:
        }
        this.showDuplicateConfirmation = false;
    }

    uncheckDuplicateNameAndLogo() {
        this.duplicateNameAndLogo = false;
        this.uncheckToggleInput("lightning-input[data-name='duplicate-name-and-logo']");
    }

    uncheckDuplicateColumnHeaders() {
        this.duplicateColumnHeaders = false;
        this.uncheckToggleInput("lightning-input[data-name='duplicate-column-headers']");
    }

    uncheckDuplicateExpandReportRows() {
        this.duplicateExpandReportRows = false;
        this.uncheckToggleInput("lightning-input[data-name='duplicate-expand-report']");
    }

    uncheckToggleInput(selector) {
        let toggleEl = this.template.querySelector(selector);
        if (toggleEl && toggleEl.checked) {
            toggleEl.checked = false;
        }
    }

    handleDuplicationConfirm() {
        switch (this.duplicateConfirmationMessage) {
            case DUPLICATE_ACCOUNTING_PERIOD_MSG:
                this.duplicateColumnHeaders = true;
                break;
            case DUPLICATE_NAME_LOGO_MSG:
                this.duplicateNameAndLogo = true;
                break;
            case EXPAND_REPORT_ROWS_MSG:
                this.duplicateExpandReportRows = true;
                break;
            default:
        }
        this.showDuplicateConfirmation = false;
    }

    handleDuplicateAccountingPeriodToggle(event) {
        this.showDuplicateConfirmation = event.detail.checked;
        this.duplicateConfirmationMessage = DUPLICATE_ACCOUNTING_PERIOD_MSG;
    }

    handleDuplicateNameLogoToggle(event) {
        this.showDuplicateConfirmation = event.detail.checked;
        this.duplicateConfirmationMessage = DUPLICATE_NAME_LOGO_MSG;
    }

    handleExpandReportRowsLedgerToggle(event) {
        this.showDuplicateConfirmation = event.detail.checked;
        this.duplicateConfirmationMessage = EXPAND_REPORT_ROWS_MSG;
    }

    populateLogoFileInfo(contentDocumentId) {
        getContentVersionInfo({contentDocumentId: contentDocumentId})
            .then(result => {
                this.settingsDTO.companyLogoId = result.value;
                this.settingsDTO.companyLogoFileName = result.label;
            })
            .catch(error => {
                console.error(error);
                this.error = error;
                this.isError = true;
            });
    }

    receiveSettings(ledgerId) {
        this.isError = false;
        this.isSpinner = true;
        getSettings({ledgerId: ledgerId})
            .then(result => {
                this.originalSettingsDTO = result;
                this.settingsDTO = CommonUtils.copyObject(this.originalSettingsDTO);
                this.isSpinner = false;
                this.isLedgerSpinner = false;
            })
            .catch(error => {
                this.error = error;
                this.isError = true;
                this.isSpinner = false;
                this.isLedgerSpinner = false;
            });
    }

    connectedCallback() {
        this.receiveSettings(null);
    }

}
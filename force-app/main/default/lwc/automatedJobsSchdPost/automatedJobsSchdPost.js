import {api, track, LightningElement} from 'lwc';
import {Constants, CommonUtils, NotificationService, LabelService} from 'c/utils';
import HAS_EDIT_PERMISSION from '@salesforce/customPermission/Accounting_Home_Settings_Write_Access';
import Labels from './labels';

const BASE_SCHD_TYPES = [
    {label: LabelService.commonAmortizationEntries},
    {label: LabelService.commonAPDisbursements},
    {label: LabelService.commonBillingsBCaps},
    {label: Labels.INF_BILLING_CASH_RECEIPTS},
    {label: LabelService.commonCashDisbursements},
    {label: LabelService.commonCashReceipts},
    {label: LabelService.commonJournalEntries},
    {label: LabelService.commonPayables},
    {label: LabelService.commonTimeCards}
];

const ERP_SCHD_TYPES = [
    {label: Labels.INF_INBOUND_ORDER_INVENTORY_MOVEMENTS},
    {
        label: Labels.INF_MANUFACTURING_INVENTORY_MOVEMENTS,
        isAvailable: (params) => params.inventoryValuationMethod === Constants.ACCT_SETTINGS.INVENTORY_VALIDATION_METHOD.STANDARD_COST
    },
    {label: Labels.INF_OUTBOUND_INVENTORY_MOVEMENTS},
    {label: Labels.INF_PURCHASE_ORDER_INVENTORY_MOVEMENTS},
    {label: Labels.INF_SALES_ORDER_INVENTORY_MOVEMENTS}
];

export default class AutomatedJobsSchdPost extends LightningElement {
    labels = LabelService;
    static RUN_NOW_STATE = {id: 'runNow', buttonLabel: LabelService.automatedJobsRunNowButton};
    static ADD_SCHD_JOBS_STATE = {id: 'addSchdJobs', buttonLabel: Labels.INF_ADD_SCHEDULED_JOBS};

    @api inventoryValuationMethod;
    @api currentState;
    @api configs;
    @api timesToExclude = [];

    @track selectedSchdTypes;

    columns = [{ label: LabelService.automatedJobsSelectSchdPostTitle, fieldName: 'label', type: 'text' }];

    schdTypes;

    get isAddSchdJobsState() {
        return this.currentState.id === AutomatedJobsSchdPost.ADD_SCHD_JOBS_STATE.id;
    }

    get isSchdJobsNotSelected() {
        return !this.selectedSchdTypes || !this.selectedSchdTypes.length;
    }

    get isTimeSlotsNotAvailable() {
        return this.isAddSchdJobsState && (!this.startTimes || !this.startTimes.length);
    }

    get startTimes() {
        return CommonUtils.startTimes(this.timesToExclude);
    }

    get userCannotEdit() {
        return !HAS_EDIT_PERMISSION;
    }

    get jobToScheduleTime() {
        return this.currentState.jobToScheduleTime + '';
    }

    connectedCallback() {
        this.showSpinner = false;
        this.selectedSchdTypes = this.currentState.selectedSchdTypes;
        this.isErpEnabled = this.configs.data.pkgs.erp.installed;
        const isAvailableParams = {inventoryValuationMethod: this.inventoryValuationMethod};
        this.schdTypes = [...BASE_SCHD_TYPES, ...(this.isErpEnabled && ERP_SCHD_TYPES || [])]
            .filter(item => !item.isAvailable || item.isAvailable(isAvailableParams))
            .map(item => ({name: item.label, ...item}))
            .sort((a, b) => {
                a = a.label.toLowerCase();
                b = b.label.toLowerCase();
                return (a < b && -1) || (a > b && 1) || 0;
            });
    }

    processJob() {
        if (this.isSchdJobsNotSelected) {
            NotificationService.displayToastMessage(
                this,
                LabelService.automatedJobsSelectedValueError,
                LabelService.commonToastErrorTitle,
                'error'
            );
        } else {
            this.currentState.id === AutomatedJobsSchdPost.ADD_SCHD_JOBS_STATE.id &&
               this.dispatchEvent(new CustomEvent('processjob')) || this.dispatchEvent(new CustomEvent('showconfirmation'));
        }
    }

    cancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleScheduleJobTimeUpdate(event) {
        this.dispatchEvent(new CustomEvent('schedulejobtimeupdate', {detail: { value: event.detail.value }}));
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedSchdTypes = selectedRows && selectedRows.map(item => item.name);
        this.dispatchEvent(new CustomEvent('rowselection', {detail: { selectedSchdTypes: this.selectedSchdTypes }}));
    }
}
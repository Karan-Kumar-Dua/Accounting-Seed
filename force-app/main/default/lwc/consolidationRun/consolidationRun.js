import { LightningElement, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import staticResource from '@salesforce/resourceUrl/accounting_resources';
import getLedgerHierarchyRecords from '@salesforce/apex/ConsolidationsHelper.getLedgerHierarchyRecords';
import isMultiCurrencyEnabled from '@salesforce/apex/ConsolidationsHelper.isMultiCurrencyEnabled';
import getLastPeriodClosed from '@salesforce/apex/ConsolidationsHelper.getLastPeriodClosed';
import getFirstPeriodOpen from '@salesforce/apex/ConsolidationsHelper.getFirstPeriodOpen';
import {NotificationService, ConsolidationStore, Constants, ErrorUtils, LabelService} from "c/utils";
import { AccountingPeriod } from "c/sobject";
import {refreshApex} from "@salesforce/apex";
import TIME_ZONE from '@salesforce/i18n/timeZone';
import { LedgerHierarchy, Ledger } from 'c/sobject';
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import Labels from './labels';

const actions = [
    { label: Labels.INF_RUN_FOR_PARENT_CONSIDERATIONS, name: 'run_for_parent' },
    { label: Labels.INF_RUN_PARENT_CONSIDERATIONS_WITH_CHILDREN, name: 'run_for_parent_with_children' },
];

const columns = [
    {
        type: "text",
        fieldName: "name",
        label: LabelService.commonHierarchy
    },
    {
        type: "text",
        fieldName: "ledger_type",
        label: LabelService.commonLedgerType
    },
    {
        type: "text",
        fieldName: "currency",
        label: LabelService.commonCurrency
    },
    {
        type: "url",
        fieldName: "last_period_url",
        label: Labels.INF_LAST_PERIOD,
        typeAttributes: {
            label: { fieldName: 'last_period' },
            target: "_blank"
        }
    },
    {
        type: "date",
        fieldName: "last_run",
        label: Labels.INF_LAST_RUN,
        typeAttributes: {
            year: "numeric",
            month: "2-digit",
            day: "numeric",
            hour: "numeric",
            minute: "numeric",
            timeZone: TIME_ZONE
        }
    },
    {
        type: "text",
        fieldName: "status",
        label: LabelService.commonStatus
    },
    {
        type: "url",
        fieldName: "generated_by_url",
        label: Labels.INF_GENERATED_BY,
        typeAttributes: {
            label: { fieldName: 'generated_by' },
            target: "_blank"
        }
    },
    {
        type: "action",
        typeAttributes: {
            rowActions: actions
        },
        cellAttributes: {
            class: { fieldName: 'cssClass' }
        }
    }
];

const requiredPickListValues = [
    Constants.LEDGER.TYPE_CONSOLIDATIONS_TRANSACTIONAL,
    Constants.LEDGER.TYPE_CONSOLIDATIONS_BUDGET
]

export default class ConsolidationRun extends LightningElement {

    accountingPeriod = AccountingPeriod;
    accountingPeriodObjectApiName = AccountingPeriod.objectApiName;

    data;
    columns;
    wiredRecords;
    labels ={...LabelService, ...Labels};

    lastPeriodClosed = null;
    firstPeriodOpen = null;
    parentLedgerHierarchyId = null;
    parentLedgerHierarchyName = null;
    runWithChildren = false;

    showNoContentPage = false;
    loaded = false;
    lh = new LedgerHierarchy();
    itemsStore = new ConsolidationStore(this.lh);
    isError = false;
    error = false;
    showPopup = false;
    showConfigWarning = false;

    get dialogTitle() {
        return (this.runWithChildren) ? Labels.INF_RUN_PARENT_CONSIDERATIONS_WITH_CHILDREN : Labels.INF_RUN_FOR_PARENT_CONSIDERATIONS;
    }

    loadLastPeriodClosed() {
        getLastPeriodClosed()
            .then(result => {
                this.lastPeriodClosed = result;
            })
            .catch(e => this.processError(e));
    }

    loadFirstPeriodOpen() {
        getFirstPeriodOpen()
            .then(result => {
                this.firstPeriodOpen = result;
            })
            .catch(e => this.processError(e));
    }

    @wire(getObjectInfo, { objectApiName: Ledger.ledgerObject })
    ledgerMetadata;

    @wire(getPicklistValues, {recordTypeId: '$ledgerMetadata.data.defaultRecordTypeId', fieldApiName: Ledger.type1})
    lhTypePicklist(result) {
        const { data } = result;
        if (data) {
            this.showConfigWarning = !this.itemsStore.isAllLedgerTypeValues(data.values.map(i => i.value), requiredPickListValues);
        }
    }

    @wire(getLedgerHierarchyRecords)
    async wiredRecord(result) {
        this.wiredRecords = result;
        const { data } = result;
        if (data) {
            if (data.rows && data.rows.length > 0) {
                await this.getIsMultiCurrencyEnabled();
                this.itemsStore.addItems(data);
                this.data = this.itemsStore.getItems();
                this.showNoContentPage = false;
            }
            else {
                this.data = [];
                this.showNoContentPage = true;
            }
            this.loaded = true;
        }
    }

    getIsMultiCurrencyEnabled() {
        return isMultiCurrencyEnabled()
            .then(result => {
                this.itemsStore.isMultiCurrencyEnabled = result;
                if (!result) {
                    columns.splice(2, 1);
                }
                this.columns = columns;

            })
            .catch(e => this.processError(e));
    }

    processError(e) {
        let {isError, error} = ErrorUtils.processError(e);
        this.error = error;
        this.isError = isError;
    }

    expandAll() {
        const treeGrid = this.template.querySelector('lightning-tree-grid');
        if (treeGrid) {
            treeGrid.expandAll();
        }
    }

    collapseAll() {
        const treeGrid = this.template.querySelector('lightning-tree-grid');
        if (treeGrid) {
            treeGrid.collapseAll();
        }
    }

    refresh() {
        refreshApex(this.wiredRecords);
        NotificationService.displayToastMessage(
            this,
            Labels.INF_PAGE_REFRESHED
        );
    }

    handleRowAction(event) {
        const row = event.detail.row;
        this.parentLedgerHierarchyId = row.Id;
        this.parentLedgerHierarchyName = row.Name;
        switch (event.detail.action.name) {
            case 'run_for_parent':
                this.runWithChildren = false;
                break;
            case 'run_for_parent_with_children':
                this.runWithChildren = true;
                break;
            default:
        }
        const runConsolidationModal = this.template.querySelector(`c-modal-popup-base[data-id="runConsolidationModal"]`);
        runConsolidationModal && runConsolidationModal.openModal();
    }

    handleRegisterDataRetriever(event) {
        event && event.detail && event.detail.dataRetrieverCallback &&
            event.detail.dataRetrieverCallback({
                id : this.parentLedgerHierarchyId,
                name : this.parentLedgerHierarchyName,
                runWithChildren : this.runWithChildren
            });
    }

    closeRunModal() {
        const runConsolidationModal = this.template.querySelector(`c-modal-popup-base[data-id="runConsolidationModal"]`);
        runConsolidationModal && runConsolidationModal.closeModal();
    }

    handleRunSuccess() {
        this.closeRunModal();
        refreshApex(this.wiredRecords);
        this.showProgressToastMessage();
    }

    showProgressToastMessage() {
        NotificationService.displayToastMessage(
            this,
            `${Labels.INF_CONSIDERATIONS_ROUTINE_RUN_FOR} ${this.parentLedgerHierarchyName} ${Labels.INF_REFRESH_PAGE_UPDATES}`,
            this.dialogTitle
        );
    }

    connectedCallback() {
        loadStyle(this, staticResource + '/css/lwc-custom-classes.css');
        this.loadLastPeriodClosed();
        this.loadFirstPeriodOpen();
    }

}
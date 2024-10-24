import {LightningElement, track, wire} from "lwc";
import getLedgerHierarchyRecords from '@salesforce/apex/ConsolidationsHelper.getLedgerHierarchyRecords';
import isMultiCurrencyEnabled from '@salesforce/apex/ConsolidationsHelper.isMultiCurrencyEnabled';
import saveLedgerHierarchySortOrders from '@salesforce/apex/ConsolidationsHelper.saveLedgerHierarchySortOrders';
import fetchConfigs from '@salesforce/apex/ConsolidationsHelper.fetchConfigs';
import { refreshApex } from '@salesforce/apex';
import { CommonUtils, ErrorUtils, NotificationService, ConsolidationStore, Constants, LabelService } from 'c/utils';
import { Ledger, LedgerHierarchy } from "c/sobject";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import Labels from './labels';

const getLedgerTypeValue = row => CommonUtils.getDataValue(LedgerHierarchy.ledger_r_type.fieldApiName, row);

const getRowActions = (row, doneCallback) => {
  switch (getLedgerTypeValue(row)) {
    case 'Consolidations-Transactional':
    case 'Consolidations-Budget':
      doneCallback([
          { label: Labels.INF_ADD_LEDGER, name: "add" },
          { label: LabelService.commonEdit, name: "edit" },
          { label: Labels.INF_REMOVE_LEDGER, name: "remove" }
      ]);
      break;
    case 'Eliminations-Transactional':
    case 'Eliminations-Budget':
      doneCallback([
        { label: LabelService.commonEdit, name: "edit" }
      ]);
      break;
    default: 
      doneCallback([
        { label: LabelService.commonEdit, name: "edit" },
        { label: Labels.INF_REMOVE_LEDGER, name: "remove" }
      ]);
  }
}

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
        type: "action",
        typeAttributes: {
            rowActions: getRowActions
        }
    }
];

const requiredPickListValues = [
  Constants.LEDGER.TYPE_CONSOLIDATIONS_TRANSACTIONAL,
  Constants.LEDGER.TYPE_CONSOLIDATIONS_BUDGET
]

export default class ConsolidationSetup extends LightningElement {

  labels = {...LabelService, ...Labels};
  data;
  columns;
  showNoContentPage = false;
  loaded = false;
  lh = new LedgerHierarchy();
  itemsStore = new ConsolidationStore(this.lh);
  isError = false;
  error = false;
  showAddLedgerModal = false;
  showEditLedgerModal = false;
  showRemoveLedgerModal = false;
  editRecordId;
  deleteRecordId;
  deleteRecordRow;
  parentLedgerHierarchyId;
  parentLedgerHierarchyName;
  wiredRecords;
  editRecordRow;
  editRecordSortOrder;
  maxEditRecordSortOrder;
  showConfigWarning = false;
  eliminationToDeleteName;

  @track specificationsByDevNames;
  @track isMultiCurrencyEnabled;

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

  connectedCallback() {
    fetchConfigs()
      .then((result) => {
        result && (
          this.specificationsByDevNames = result.specificationsByDevNames,
          this.isMultiCurrencyEnabled = result.isMultiCurrencyEnabled
        );
      })
      .catch()
      .finally();
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

  create() {
    const createHierarchyModal = this.fetchModal('createHierarchyModal');
    createHierarchyModal && createHierarchyModal.openModal();
  }

  closeCreate() {
    const createHierarchyModal = this.fetchModal('createHierarchyModal');
    createHierarchyModal && createHierarchyModal.closeModal();
    refreshApex(this.wiredRecords);
  }

  fetchModal(dataId) {
    return this.template.querySelector(`c-modal-popup-base[data-id="${dataId}"]`);
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

  processError(e) {
    let {isError, error} = ErrorUtils.processError(e);
    this.error = error;
    this.isError = isError;
  }

  handleRowAction(event) {
    const row = event.detail.row;
    switch (event.detail.action.name) {
      case 'add':
        this.handleCreate(row);
        break;
      case 'edit':
        this.handleEdit(row);
        break;
      case 'remove':
        this.handleRemove(row);
      default:
    }
  }

  handleCreate(row) {
    this.editRecordId = undefined;
    this.parentLedgerHierarchyId = row.Id;
    this.parentLedgerHierarchyName = row.Name;
    const addLedgerModal = this.fetchModal('addLedgerModal');
    addLedgerModal && addLedgerModal.openModal();
  }

  handleEdit(row) {
    this.editRecordRow = row;
    this.editRecordId = row.Id;
    this.editRecordSortOrder = row[this.lh.sort_order];
    this.maxEditRecordSortOrder = this.itemsStore.getMaxSortOrder(row);
    const editLedgerModal = this.fetchModal('editLedgerModal');
    editLedgerModal && editLedgerModal.openModal();
  }

  handleRemove(row){
    this.deleteRecordId = row.Id;
    this.deleteRecordRow = row;
    this.eliminationToDeleteName = this.getEliminationLedger(row.Id);
    const removeLedgerModal = this.fetchModal('removeLedgerModal');
    removeLedgerModal && removeLedgerModal.openModal();
  }

  processError(e) {
    let {isError, error} = ErrorUtils.processError(e);
    this.error = error;
    this.isError = isError;
  }

  closeModals() {
    const editLedgerModal = this.fetchModal('editLedgerModal');
    editLedgerModal && editLedgerModal.closeModal();

    const addLedgerModal = this.fetchModal('addLedgerModal');
    addLedgerModal && addLedgerModal.closeModal();

    const removeLedgerModal = this.fetchModal('removeLedgerModal');
    removeLedgerModal && removeLedgerModal.closeModal();
  }

  closeModalsRefresh({ detail }) {
    if (detail.message) {
      this.closeModals();
      NotificationService.displayToastMessage(this, detail.message, LabelService.commonSaveSuccessful);
      refreshApex(this.wiredRecords);

      const self = this;
      detail.isSaveNew && window.setTimeout(() => {
        const addLedgerModal = self.fetchModal('addLedgerModal');
        addLedgerModal && addLedgerModal.openModal();
      }, 1000);
    }
  }

  handleEditSuccess(event) {
    const editLedgerModal = this.fetchModal('editLedgerModal');
    if (editLedgerModal && editLedgerModal.isOpen) {
      if (parseInt(event.detail.sortOrder) !== this.editRecordRow[this.lh.sort_order]) {
        let ledgerHierarchies = this.itemsStore.getSortOrderUpdateItems(this.editRecordRow, event.detail.sortOrder)
          .map(item => ({ Id: item.Id, [this.lh.sort_order]: item[this.lh.sort_order]}));
        this.saveHierarchySortOrders(ledgerHierarchies);
      }
      else {
        refreshApex(this.wiredRecords);
      }
      event.detail.message && NotificationService.displayToastMessage(this, event.detail.message, LabelService.commonSaveSuccessful);
    }
    this.closeModals();
  }

  saveHierarchySortOrders(hierarchies) {
    return saveLedgerHierarchySortOrders({ledgerHierarchies: hierarchies})
      .then(result => {
        if (result.isSuccess) {
          refreshApex(this.wiredRecords);
        }
      })
      .catch(e => this.processError(e));
  }

  handleDeleteSuccess({ detail }) {
    this.closeModals();
    let ledgerHierarchies = this.itemsStore.getSortOrderUpdateItems(this.deleteRecordRow, 9999)
      .filter(item => item.Id !== this.deleteRecordId);
    this.saveHierarchySortOrders(ledgerHierarchies);

    const errorMsg = detail.message && detail.message
      .replace(detail.patternParts.nameOfELPattern, this.getEliminationLedger(detail.id));
    NotificationService.displayToastMessage(this, errorMsg, LabelService.commonSuccess);
  }

  handleDeleteError({ detail }) {
    const { topErrors } = ErrorUtils.processRecordApiErrors(detail.bodyError)
    const errorMsg = (topErrors && topErrors.length && topErrors.map(item => item.message)[0]) || detail.bodyError.message;
    NotificationService.displayToastMessage(this, errorMsg, LabelService.commonToastErrorTitle, 'error');
  }

  getEliminationLedger(ledgerId) {
    const itemsMapByParent = this.itemsStore.itemsMapByParent;
    const eliminationLedger =
        itemsMapByParent
          && itemsMapByParent[ledgerId]
          && itemsMapByParent[ledgerId].find(
            ledger => ledger.ledger_type === 'Eliminations-Transactional' || ledger.ledger_type === 'Eliminations-Budget'
          );
    return eliminationLedger && eliminationLedger[LedgerHierarchy.xname.fieldApiName];
  }

}
import { api, wire, track } from 'lwc';
import { deleteRecord, getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { LedgerHierarchy } from "c/sobject";
import { ModalLightningElement, LabelService } from 'c/utils';
import Labels from './labels';

const FIELDS = [LedgerHierarchy.xname, LedgerHierarchy.ledger_r_type];
const CONSOLIDATION_TYPES = ['Consolidations-Transactional', 'Consolidations-Budget'];

export default class ConsolidationDeleteHierarchy extends ModalLightningElement {
    labels = {...LabelService, ...Labels};
    ledgerHierarchy = LedgerHierarchy;
    _hasSpinner = false;

    @track ledgerHierarchyToDeleteName;
    @api deleteRecordId;
    @api eliminationToDeleteName;

    get hasSpinner() {
        return !this.ledgerHierarchyToDeleteName || !this.ledgerHierarchyToDeleteLedgerType || this._hasSpinner;
    }

    get showMessageCLRemoving() {
        return CONSOLIDATION_TYPES.includes(this.ledgerHierarchyToDeleteLedgerType);
    }

    @wire(getRecord,{recordId:'$deleteRecordId', fields: FIELDS})
    ledgerHierarchyRecordResult({data, error}){
        if(data){
            this.ledgerHierarchyToDeleteName = getFieldValue(data, this.ledgerHierarchy.xname);
            this.ledgerHierarchyToDeleteLedgerType = getFieldValue(data, this.ledgerHierarchy.ledger_r_type);
        }
    }
    
    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleConfirm() {
        this.showSpinner();
        deleteRecord(this.deleteRecordId)
            .then(() => {
                const nameOfELPattern = '{nameOfEL}';
                this.dispatchEvent(
                    new CustomEvent(
                        'success', {
                            detail: {
                                id: this.deleteRecordId,
                                patternParts: { nameOfELPattern: nameOfELPattern },
                                message:
                                    CONSOLIDATION_TYPES.includes(this.ledgerHierarchyToDeleteLedgerType)
                                        ? `${LabelService.commonThe} ${this.ledgerHierarchyToDeleteName} ${Labels.INF_LEDGER_AND_CHILD_ELIMINATIONS} ${nameOfELPattern} ${Labels.INF_HAVE_BEEN_REMOVED}.`
                                        : `${LabelService.commonThe} ${this.ledgerHierarchyToDeleteName} ${Labels.INF_LEDGER_HAS_BEEN_REMOVED}`
                            }
                        }
                    )
                );
            })
            .catch(error => {
                this.dispatchEvent(new CustomEvent('error', { detail: { bodyError: error.body }}));
            })
            .finally(() => {
                this.hideSpinner();
            });
    }

    showSpinner() {
        this._hasSpinner = true;
    }

    hideSpinner() {
        this._hasSpinner = false;
    }
}
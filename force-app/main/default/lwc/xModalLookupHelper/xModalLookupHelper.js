import { LightningElement,api } from 'lwc';
import { LabelService } from 'c/utils';

export default class XModalLookupHelper extends LightningElement {
    labels = LabelService;
    @api column;
    @api row;
    @api objectName;

    get searchObject(){
        return this.column.typeAttributes.referenceObject;
    }
    get fieldValue(){
        return this.row[this.column.apiName];
    }
    handleSelectionChange(evt){
        const mutation = new CustomEvent('selectionchange', {
            detail: {
                apiName: this.column.apiName,
                value: evt.detail ? evt.detail.recordId : null,
                label: evt.detail ? evt.detail.recordName : null
            }
        });
        this.dispatchEvent(mutation);
    }
}
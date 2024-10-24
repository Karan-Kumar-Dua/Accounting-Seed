import {LightningElement, api} from 'lwc';

export default class CustomDateInput extends LightningElement {

    @api date;
    @api editMode = false;
    @api rowId;
    @api colId;

    handleValueChange(event) {
        let currentValue = event.target.value;
        this.fireCellChangeEvent(currentValue);
    }

    fireCellChangeEvent(value) {
        const event = new CustomEvent('customcellchange', {
            composed: true,
            bubbles: true,
            cancelable: true,
            detail: {
                rowId: this.rowId,
                colId: this.colId,
                value: value
            }
        });
        this.dispatchEvent(event);
    }

}
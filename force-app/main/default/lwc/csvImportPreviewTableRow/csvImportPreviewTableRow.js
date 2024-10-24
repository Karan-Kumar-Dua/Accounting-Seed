import { LightningElement,api } from 'lwc';

export default class CsvImportPreviewTableRow extends LightningElement {
    @api columns;
    @api rowData;
    @api fieldDefinitions;
    @api record;
}
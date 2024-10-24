import {api, LightningElement, wire} from 'lwc';
import { LabelService, CommonUtils } from "c/utils";
import retrieveLines from '@salesforce/apex/OpportunityCalcTaxController.retrieveLines';
import { OpportunityLineItem, TaxGroup, Product } from 'c/sobject';

export default class OpportunityCalcTaxLlpTable extends LightningElement {
    labels = LabelService;
    @api recordId;
    @api isAvalaraTax;
    @api isMultiCurrencyEnabled;
    @api currencyCode;

    page;
    data = [];
    totalRecords;
    pageSize = 10;
    pageOffset = 0;
    opportunityLineItem = new OpportunityLineItem();
    taxGroup = new TaxGroup();
    taxGroupApiName = TaxGroup.objectApiName;

    @api
    get items() {
        return this.data;
    }
    set items(value = []) {
        this._items = value;
        this.processData();
    }

    processData() {
        if (this._items && this.taxProductLines && this.taxRateProductsByIds) {
            this.data = this.setAdditionalFields(this._items?.sourceObjLines);
            this.totalRecords = this.data?.length;
            this.page = this.data?.slice(this.pageOffset, this.pageOffset + this.pageSize);
        }
    }

    @wire(retrieveLines, {opportunityId: '$recordId'})
    fetchLines(result) {
        result?.data && (
            this.taxProductLines = result.data.taxProductLines,
            this.taxRateProductsByIds = result.data.taxRateProductsByIds,
            this.processData()
        );
    }

    handlePageChange({ detail: offset }) {
        this.pageOffset = offset;
        this.page = this.items.slice(offset, offset + this.pageSize);
    }

    setAdditionalFields(data) {
        return data && data
            .map(item => this.copy(item))
            .map(item => this.setField(item));
    }

    copy(item) {
        let clone = {...item};
        return clone;
    }

    setField(item) {
        item.urlLink = '/' + (this.taxRateProductsByIds && this.taxRateProductsByIds[item.Product2Id]?.Id);
        item.Name = this.taxRateProductsByIds && this.taxRateProductsByIds[item.Product2Id]?.Name;
        item.taxAmount = item.UnitPrice;
        item.taxRatePercentage = this.taxRateProductsByIds && this.taxRateProductsByIds[item.Product2Id] &&
                this.taxRateProductsByIds[item.Product2Id][Product.taxRate.fieldApiName];

        item.products = this.taxProductLines.map(line => ({
            taxRatePercentage : item.taxRatePercentage,
            subtotal : (line[OpportunityLineItem.subtotal.fieldApiName] * this.getDiscountAmount(line)),
            product : line.Product2?.Name,
            productUrlLink : '/' + line.Product2?.Id,
            taxAmount : (item.taxRatePercentage && line[OpportunityLineItem.subtotal.fieldApiName] &&
                (item.taxRatePercentage * line[OpportunityLineItem.subtotal.fieldApiName] * 0.01) * this.getDiscountAmount(line)) || 0
        }));

        return item;
    }

    getDiscountAmount = item => (100 - this.getDiscount(item)) / 100;

    getDiscount = item => (item[this.opportunityLineItem.discount] ? item[this.opportunityLineItem.discount] : 0);
}
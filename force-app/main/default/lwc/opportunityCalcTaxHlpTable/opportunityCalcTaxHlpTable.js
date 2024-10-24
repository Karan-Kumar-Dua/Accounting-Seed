import {api, track, LightningElement} from 'lwc';
import { LabelService, CommonUtils } from "c/utils";
import { OpportunityLineItem, TaxGroup} from 'c/sobject';
import { keywords } from 'c/lookupKeywords';

export default class OpportunityCalcTaxHlpTable extends LightningElement {
    labels = LabelService;
    @api isAvalaraTax;
    @api isMultiCurrencyEnabled;
    @api currencyCode;
    @track page;
    data = [];
    totalRecords;
    pageSize = 10;
    pageOffset = 0;
    opportunityLineItem = new OpportunityLineItem();
    taxGroup = new TaxGroup();
    taxGroupApiName = TaxGroup.objectApiName;
    taxGroupRetrieveFields = {
        [TaxGroup.objectApiName]: [
            TaxGroup.combinedTaxRate.fieldApiName
        ]
    };

    taxGroupSearchFilter = {
        type: keywords.type.STRING,
        field: TaxGroup.tax_type.fieldApiName,
        op: keywords.op.IN,
        val: ['Sales and Purchase', 'Sales']
    };

    @api
    get items() {
        return this.data;
    }
    set items(value = []) {
        this.data = this.setAdditionalFields(value?.sourceObjLines);
        this.totalRecords = this.data?.length;
        this.page = this.data?.slice(this.pageOffset, this.pageOffset + this.pageSize);
    }

    get showDiscount() {
        return this.data && this.data.some(item => item.hasOwnProperty('Discount'));
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
        item.urlLink = CommonUtils.getRecordViewPath(item.Id);
        item.taxGroup = this.previewParamsByIds && this.previewParamsByIds[item.Id] ?
            this.previewParamsByIds[item.Id].taxSettingId : item[this.opportunityLineItem.tax_group];
        item.taxAmount = item[this.opportunityLineItem.tax_amount];
        item.discount = this.getDiscountAmount(item);
        item.subtotal = (item[this.opportunityLineItem.unit_price] * (100 - this.getDiscount(item)) / 100) * item[this.opportunityLineItem.quantity];
        item.estimatedTotal = item[this.opportunityLineItem.tax_amount] + item.subtotal;
        return item;
    }

    handleSelectionChange() {
        const detail = {};
        for (let item of this.data) {
            const ledgerLookup = this.template.querySelector(`c-lookup-a[data-id="${item.Id}"]`);
            if (ledgerLookup) {
                const selected = ledgerLookup.getSelection() && ledgerLookup.getSelection()[0];
                detail[item.Id] = {
                    taxSettingId: selected && (selected.Id || selected.id),
                    taxSettingCombinedRate: selected && selected[this.taxGroup.combinedTaxRate] || 0
                };
            }
        }
        this.previewParamsByIds = {...this.previewParamsByIds, ...detail};
        this.dispatchEvent(new CustomEvent('taxgroupchange', { detail }));
    }

    getDiscountAmount = item => (item[this.opportunityLineItem.unit_price] * item[this.opportunityLineItem.quantity]) * (this.getDiscount(item) / 100);

    getDiscount = item => (item[this.opportunityLineItem.discount] ? item[this.opportunityLineItem.discount] : 0);
}
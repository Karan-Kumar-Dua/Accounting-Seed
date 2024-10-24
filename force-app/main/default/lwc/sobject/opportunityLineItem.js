import TAX_AMOUNT from '@salesforce/schema/OpportunityLineItem.Tax_Amount__c';
import TOTAL_PRICE from '@salesforce/schema/OpportunityLineItem.TotalPrice';
import SUBTOTAL from '@salesforce/schema/OpportunityLineItem.Subtotal';
import UNIT_PRICE from '@salesforce/schema/OpportunityLineItem.UnitPrice';
import QUANTITY from '@salesforce/schema/OpportunityLineItem.Quantity';
import DISCOUNT from '@salesforce/schema/OpportunityLineItem.Discount';
import TAX_GROUP from '@salesforce/schema/OpportunityLineItem.Tax_Group__c';
import PRODUCT from '@salesforce/schema/OpportunityLineItem.Product2Id';

import PRODUCT_R_TAX_GROUP_ID from '@salesforce/schema/OpportunityLineItem.PricebookEntry.Product2.Tax_Group__r.Id';
import TAX_GROUP_ID from '@salesforce/schema/OpportunityLineItem.Tax_Group__r.Id';

export default class OpportunityLineItem {

    static tax_amount = TAX_AMOUNT;
    static total_price = TOTAL_PRICE;
    static subtotal = SUBTOTAL;
    static unit_price = UNIT_PRICE;
    static quantity = QUANTITY;
    static discount = DISCOUNT;
    static tax_group = TAX_GROUP;
    static product = PRODUCT;

    static product_r_tax_group_id = PRODUCT_R_TAX_GROUP_ID;
    static tax_group_id = TAX_GROUP_ID;

    tax_amount = TAX_AMOUNT.fieldApiName;
    total_price = TOTAL_PRICE.fieldApiName;
    subtotal = SUBTOTAL.fieldApiName;
    unit_price = UNIT_PRICE.fieldApiName;
    quantity = QUANTITY.fieldApiName;
    discount = DISCOUNT.fieldApiName;
    tax_group = TAX_GROUP.fieldApiName;
    product = PRODUCT.fieldApiName;

    product_r_tax_group_id = PRODUCT_R_TAX_GROUP_ID.fieldApiName;
    tax_group_id = TAX_GROUP_ID.fieldApiName;

}
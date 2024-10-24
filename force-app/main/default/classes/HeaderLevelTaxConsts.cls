/**
 * *** DO NOT REFERENCE STANDARD OBJECTS HERE (ex. OpportunityLineItem) ***
 * 
 * Contains constants for HLP.
 * 
 * Constants were removed from HeaderLevelTaxHelper due to post 
 * install script errors. The post install user doesn't have access 
 * to OpportunityLineItem which is referenced by a static var definition
 * in HeaderLevelTaxHelper.
 */
public with sharing class HeaderLevelTaxConsts {
    public static final String NO_SUPPORT_INFO_MESSAGE = Label.INF_NO_SUPPORT;
    public static final String UNIT_COST_REQUIRED_ERROR = Label.ERR_UNIT_COST_REQUIRED;
    public static final String HEADER_LEVEL_POST = 'Header-Level Post';
    public static final String LINE_LEVEL_POST = 'Line-Level Post';
    public static final String HEADER_LEVEL_POSTING_SET_ERROR = Label.ERR_HEADER_LEVEL_POSTING_SET;
    public static final List<String> SALES_TAX_RATE_TYPES = new List<String> {'Sales', 'Sales and Purchase'};
    public static final List<String> PURCHASE_TAX_RATE_TYPES = new List<String> {'Purchase', 'Sales and Purchase'};
    public static final String NOT_SALES_TAX_GROUP_ERROR = Label.ERR_NOT_SALES_TAX_GROUP;
    public static final String NOT_PURCHASE_TAX_GROUP_ERROR = Label.ERR_NOT_PURCHASE_TAX_GROUP;
    public static final String TAX_GROUP_WITHOUT_TAX_RATE_ERROR = Label.ERR_TAX_GROUP_WITHOUT_TAX_RATE;
}
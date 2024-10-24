/**
 * SOQLBuilder provides an object-oriented way of building SOQL queries without resorting to string manipulation.
 * This class is not meant to be used as a replacement for all SOQL queries, and due to the relativley high overhead in both CPU and describe calls
 * should be used in places where highly dynamic queries, such as those that include field sets or are mutated heavilly
 * in multiple locations are a good fit for use with SOQLBuilder.
 * 
 * To use call construct a new instance for each query you intend to make.
 * To add additional fields to the query make use of the selectField(s) methods.
 *
 * Currently the WHERE clause of the query is manipulated as a single string, and is decidedly less OO-styled than other methods.
 * This is expected to be expanded upon in the future.
 * 
 * To include one or more ORDER BY clause(s), use one of the addOrdering methods.  If not specified, the "NULLS FIRST" keywords
 * will be included by default. Constructing Ordering instances manually is discouraged.
 * 
 * Subselect Queries are supported with the subselectQuery methods.  
 * More than one sub-query can be added to a single query, but sub-queries can only be 1 level deep.  
 * An exception will thrown from the subselectQuery method when there is an attempt to add a subquery to a sub-query
 * or to add a subquery to a query with an invalid relationship.
 *
 * Current limitations:
 * - Aggregate functions are not currently supported.
 * - Cross-object references currently require using String argument(s) to selectField(s).
 * - The behavior of serializing and deserializing an SOQLBuilder instance is currently untested and undefined.
 *
 * There is a google doc providing additional guideance on the use of this class with field sets at
 * https://docs.google.com/a/financialforce.com/document/d/1I4cxN4xHT4UJj_3Oi0YBL_MJ5chm-KG8kMN1D1un8-g/edit?usp=sharing
**/
public class SOQLBuilder { //No explicit sharing declaration - inherit from caller
    public enum SortOrder {ASCENDING, DESCENDING}

	/**
	 * This property is read-only and may not be set after instantiation.
	 * The {@link Schema.SObjectType} token of the SObject that will be used in the FROM clause of the resultant query.
	**/
    public Schema.SObjectType table {get; private set;}
    @TestVisible
    private Set<QueryField> fields;
    private String conditionExpression;
    private Integer limitCount;
    private Integer offset;
    private List<Ordering> order;
	/**
	/* Integrate checking for READ Field Level Security within the selectField(s) methods
	/* This can optionally be enforced (or not) by calling the setEnforceFLS method prior to calling 
	/* one of the selectField or selectFieldset methods.
	**/
    private Boolean enforceFLS;

    private Boolean sortSelectFields = true;
	/**
	 * The relationship and  subselectQueryMap variables are used to support subselect queries.  Subselects can be added to 
	 * a query, as long as it isn't a subselect query itself.  You may have many subselects inside
	 * a query, but they may only be 1 level deep (no subselect inside a subselect)
	 * to add a subselect, call the subselectQuery method, passing in the ChildRelationship.
	**/
    private Schema.ChildRelationship relationship;
    private Map<Schema.ChildRelationship, SOQLBuilder> subselectQueryMap;

    private SOQLAccessDecisionUtil accessDecisionUtil;

    private QueryField getFieldToken(String fieldName) {
        QueryField result;
        if (!fieldName.contains('.')) { //single field
            Schema.SObjectField token = SchemaDescribe.getDescribe(table).getField(fieldName.toLowerCase());
            if (token == NULL) {
                throw new InvalidFieldException(fieldName, this.table);
            }

            if (enforceFLS) {
                SFDCSecurityUtils.flsInspector.addFlsInspectionResult(SFDCSecurityUtils.checkFieldIsReadable(this.table, token));
            }

            result = new QueryField(token);
        }
        else { //traversing FK relationship(s)
            List<Schema.SObjectField> fieldPath = new List<Schema.SObjectField>();
            Schema.sObjectType lastSObjectType = table;
            Iterator<String> i = fieldName.split('\\.').iterator();
            while (i.hasNext()) {
                String field = i.next();
                Schema.SObjectField token = SchemaDescribe.getDescribe(lastSObjectType).getField(field.toLowerCase());
                if (token != NULL && enforceFLS) {
                    SFDCSecurityUtils.flsInspector.addFlsInspectionResult(SFDCSecurityUtils.checkFieldIsReadable(lastSObjectType, token));
                }

                if (token != NULL && i.hasNext() && token.getDescribe().getSOAPType() == Schema.SOAPType.ID) {
                    //KNOWN ISSUE:polymorphic fields need to have the correct index from the collection selected for the object otherwise fields 
                    //may be selected for an object in which they do not exist
                    lastSObjectType = token.getDescribe().getReferenceTo()[0]; //if it's polymorphic doesn't matter which one we get
                    fieldPath.add(token);
                }
                else if (token != NULL && !i.hasNext()) {
                    fieldPath.add(token);
                }
                else {
                    if (token == NULL) {
                        throw new InvalidFieldException(field, lastSObjectType);
                    }
                    else {
                        throw new NonReferenceFieldException(lastSObjectType + '.' + field + Label.COMMON_NOT_LOOKUP_OR_MDFIELD_USED_IN_CROSS_OBJECT_QUERY);
                    }
                }
            }
            result = new QueryField(fieldPath);
        }

        return result;
    }

	/**
	 * SOQLBuilder instances will be considered equal if they produce the same SOQL query.
	 * A faster comparison will first be attempted to check if they apply to the same table, and contain the same number of fields selected.
	 * This method will never return true if the provided object is not an instance of SOQLBuilder.
	 * @param obj the object to check equality of.
	**/
    public Boolean equals(Object obj) {
        if (!(obj instanceof SOQLBuilder) || ((SOQLBuilder)obj).table != this.table || ((SOQLBuilder)obj).fields.size() != this.fields.size()) {
            return false;
        }
        return ((SOQLBuilder)obj).toSOQL() == this.toSOQL();
    }
	/**
	 * Construct a new SOQLBuilder instance with no options other than the FROM caluse.
	 * You *must* call selectField(s) before {@link #toSOQL} will return a valid, runnable query.
	 * @param table	the SObject to be used in the FROM clause of the resultant query. This sets the value of {@link #table}.
	**/
    public SOQLBuilder(Schema.SObjectType table) {
        this.table = table;
        fields = new Set<QueryField>();
        order = new List<Ordering>();
        enforceFLS = false;
    }
	/**
	 * Construct a new SOQLBuilder instance with no options other than the FROM clause and the relationship.
	 * This should be used when constructing a subquery query for addition to a parent query. 
	 * Objects created with this constructor cannot be added to another object using the subselectQuery method.
	 * You *must* call selectField(s) before {@link #toSOQL} will return a valid, runnable query.
	 * @param relationship the ChildRelationship to be used in the FROM Clause of the resultant Query (when set overrides value of table). This sets the value of {@link #relationship} and {@link #table}.
	**/
    private SOQLBuilder(Schema.ChildRelationship relationship) {
        this(relationship.getChildSObject());
        this.relationship = relationship;
    }
	/**
	 * This method checks to see if the User has Read Access on {@link #table}. 
	 * Asserts true if User has access.
	 **/
    public SOQLBuilder assertIsAccessible() {
        SFDCSecurityUtils.checkObjectIsReadable(table);
        return this;
    }
	/**
	 * This method sets a flag to indicate that this query should have FLS Read
	 * permission enforced.  If this method is not called, the default behavior
	 * is that FLS read permission will not be checked.
	 * @param enforce whether to enforce field level security (read)
	 **/
    public SOQLBuilder setEnforceFLS(Boolean enforce) {
        this.enforceFLS = enforce;
        return this;
    }

    public SOQLBuilder setStripInaccessible() {
        return setStripInaccessible(AccessType.READABLE, true);
    }

    public SOQLBuilder setStripInaccessible(AccessType enforceFLSType) {
        return setStripInaccessible(enforceFLSType, true);
    }

    public SOQLBuilder setStripInaccessible(AccessType enforceFLSType, Boolean enforceCRUD) {
        this.accessDecisionUtil = new SOQLAccessDecisionUtil();
        this.accessDecisionUtil.setAccessType(enforceFLSType);
        this.accessDecisionUtil.setEnforceCRUD(enforceCRUD);
        return this;
    }
	/**
	 * Sets a flag to indicate that this query should have ordered
	 * query fields in the select statement (this at a small cost to performance).
	 * If you are processing large query sets, you should switch this off.
	 * @param whether or not select fields should be sorted in the soql statement.
	 **/
    public SOQLBuilder setSortSelectFields(Boolean doSort) {
        this.sortSelectFields = doSort;
        return this;
    }
	
	/**
	 * Selects a single field from the SObject specified in {@link #table}.
	 * Selecting fields is idempotent, if this field is already selected calling this method will have no additional impact.
	 * @param fieldName the API name of the field to add to the query's SELECT clause.
	 **/
    public SOQLBuilder selectField(String fieldName) {
        fields.add( getFieldToken(fieldName) );
        return this;
    }
	/**
	 * Selects a field, avoiding the possible ambiguitiy of String API names.
	 * @see #selectField(String)
	 * @param field the {@link Schema.SObjectField} to select with this query.
	 * @exception InvalidFieldException If the field is null {@code field}.
	**/
    public SOQLBuilder selectField(Schema.SObjectField field) {
        if (field == NULL) {
            throw new InvalidFieldException(null,this.table);
        }

        if (enforceFLS) {
            SFDCSecurityUtils.flsInspector.addFlsInspectionResult(SFDCSecurityUtils.checkFieldIsReadable(table, field));
        }

        SFDCSecurityUtils.flsInspector.checkResults();

        fields.add(new QueryField(field));
        return this;
    }
	/**
	 * Selects multiple fields. This acts the same as calling {@link #selectField(String)} multiple times.
	 * @param fieldNames the Set of field API names to select.
	**/
    public SOQLBuilder selectFields(Set<String> fieldNames) {
        List<String> fieldList = new List<String>();
        Set<QueryField> toAdd = new Set<QueryField>();
        for (String fieldName : fieldNames) {
            toAdd.add(getFieldToken(fieldName));
        }
        SFDCSecurityUtils.flsInspector.checkResults();
        fields.addAll(toAdd);
        return this;
    }
	/**
	 * Selects multiple fields. This acts the same as calling {@link #selectField(String)} multiple times.
	 * @param fieldNames the List of field API names to select.
	**/
    public SOQLBuilder selectFields(List<String> fieldNames) {
        Set<QueryField> toAdd = new Set<QueryField>();
        for (String fieldName : fieldNames) {
            toAdd.add(getFieldToken(fieldName));
        }
        SFDCSecurityUtils.flsInspector.checkResults();
        fields.addAll(toAdd);
        return this;
    }
	/**
	 * Selects multiple fields. This acts the same as calling {@link #selectField(Schema.SObjectField)} multiple times.
	 * @param fieldNames the set of {@link Schema.SObjectField}s to select.
	 * @exception InvalidFieldException if the fields are null {@code fields}.
	**/
    public SOQLBuilder selectFields(Set<Schema.SObjectField> fields) {
        for (Schema.SObjectField token : fields) {
            if (token == NULL) {
                throw new InvalidFieldException();
            }
            if (enforceFLS) {
                SFDCSecurityUtils.flsInspector.addFlsInspectionResult(SFDCSecurityUtils.checkFieldIsReadable(table, token));
            }
            SFDCSecurityUtils.flsInspector.checkResults();

            this.fields.add(new QueryField(token));
        }
        return this;
    }
	/**
	 * Selects multiple fields. This acts the same as calling {@link #selectField(Schema.SObjectField)} multiple times.
	 * @param fieldNames the set of {@link Schema.SObjectField}s to select.
	 * @exception InvalidFieldException if the fields are null {@code fields}.	 
	**/
    public SOQLBuilder selectFields(List<Schema.SObjectField> fields) {
        for (Schema.SObjectField token : fields) {
            if (token == NULL) {
                throw new InvalidFieldException();
            }
            if (enforceFLS) {
                SFDCSecurityUtils.flsInspector.addFlsInspectionResult(SFDCSecurityUtils.checkFieldIsReadable(table, token));
            }
            SFDCSecurityUtils.flsInspector.checkResults();
            this.fields.add(new QueryField(token));
        }
        return this;
    }
	/**
	 * @see #selectFieldSet(Schema.FieldSet,Boolean)
	**/
    public SOQLBuilder selectFieldSet(Schema.FieldSet fieldSet) {
        return selectFieldSet(fieldSet, true);
    }
	/**
	 * This is equivielent to iterating the fields in the field set and calling {@link #selectField(String)} on each.
	 * @param fieldSet Select all fields included in the field set. 
	 * @param allowCrossObject if false this method will throw an exception if any fields in the field set reference fields on a related record.
	 * @exception InvalidFieldSetException if the fieldset is invalid for table {@code fields}.	 
	**/
    public SOQLBuilder selectFieldSet(Schema.FieldSet fieldSet, Boolean allowCrossObject) {
        if (fieldSet.getSObjectType() != table) {
            throw new InvalidFieldSetException(Label.COMMON_FIELD_SET + fieldSet.getName() + Label.COMMON_NOT_FOR_SOBJECT_TYPE + table + '"');
        }

        for (Schema.FieldSetMember field : fieldSet.getFields()) {
            if (!allowCrossObject && field.getFieldPath().contains('.')) {
                throw new InvalidFieldSetException(Label.COMMON_CROSS_OBJECT_FIELDS_NOT_ALLOWED + field.getFieldPath() + Label.COMMON_IS_CROSS_OBJECT_FIELD);
            }

            fields.add(getFieldToken(field.getFieldPath()));
        }
        return this;
    }
	/**
	 * @param conditionExpression Sets the WHERE clause to the string provided. Do not include the "WHERE".
	**/
    public SOQLBuilder setCondition(String conditionExpression) {
        this.conditionExpression = conditionExpression;
        return this;
    }
	/**
	 * @returns the current value of the WHERE clause, if any, as set by {@link #setCondition}
	**/
    public String getCondition() {
        return this.conditionExpression;
    }
	/**
	 * @param limitCount if not null causes a LIMIT caluse to be added to the resulting query.
	**/
    public SOQLBuilder setLimit(Integer limitCount) {
        this.limitCount = limitCount;
        return this;
    }
	/**
	 * @returns the current value of the LIMIT clause, if any.
	**/
    public Integer getLimit() {
        return this.limitCount;
    }

    public SOQLBuilder setOffset(Integer offset) {
        this.offset = offset;
        return this;
    }

    public Integer getOffset() {
        return this.offset;
    }
	/**
	 * @param o an instance of {@link SOQLBuilder.Ordering} to be added to the query's ORDER BY clause.
	**/
    public SOQLBuilder addOrdering(Ordering o) {
        this.order.add(o);
        return this;
    }
	/**
	 * @returns the list of orderings that will be used as the query's ORDER BY clause. You may remove elements from the returned list, or otherwise mutate it, to remove previously added orderings.
	**/
    public List<Ordering> getOrderings() {
        return this.order;
    }
	/**
	 * @returns the selected fields
	 **/
    public Set<QueryField> getSelectedFields() {
        return this.fields;
    }


	/**
	 * Add a subquery query to this query.  If a subquery for this relationshipName already exists, it will be returned.
	 * If not, a new one will be created and returned.
	 * @exception InvalidSubqueryRelationshipException If this method is called on a subselectQuery or with an invalid relationship 
	 * @param relationshipName The relationshipName to be added as a subquery
	**/
    public SOQLBuilder subselectQuery(String relationshipName) {
        return subselectQuery(relationshipName, false);
    }
	/**
	 * Add a subquery query to this query.  If a subquery for this relationship already exists, it will be returned.
	 * If not, a new one will be created and returned.
	 * @exception InvalidSubqueryRelationshipException If this method is called on a subselectQuery or with an invalid relationship 
	 * @param relationshipName The relationshipName to be added as a subquery
	 * @param assertIsAccessible indicates whether to check if the user has access to the subquery object
	**/
    public SOQLBuilder subselectQuery(String relationshipName, Boolean assertIsAccessible) {
        ChildRelationship relationship = getChildRelationship(relationshipName);
        if (relationship != NULL) {
            return setSubselectQuery(relationship, assertIsAccessible);
        }
        throw new InvalidSubqueryRelationshipException(Label.ERR_INVALID_CALL_TO_SUBSELECT_QUERY + relationshipName + Label.ERR_RELATIONSHIP_DOES_NOT_EXIST + table.getDescribe().getName());
    }
	/**
	 * Add a subquery query to this query.  If a subquery for this relationshipName already exists, it will be returned.
	 * If not, a new one will be created and returned.
	 * @exception InvalidSubqueryRelationshipException If this method is called on a subselectQuery or with an invalid relationship 
	 * @param relationship The ChildRelationship to be added as a subquery
	**/
    public SOQLBuilder subselectQuery(ChildRelationship relationship) {
        return subselectQuery(relationship, false);
    }
	/**
	 * Add a subquery query to this query.  If a subquery for this relationship already exists, it will be returned.
	 * If not, a new one will be created and returned.
	 * @exception InvalidSubqueryRelationshipException If this method is called on a subselectQuery or with an invalid relationship 
	 * @param relationship The ChildRelationship to be added as a subquery
	 * @param assertIsAccessible indicates whether to check if the user has access to the subquery object
	**/
    public SOQLBuilder subselectQuery(ChildRelationship relationship, Boolean assertIsAccessible) {
        return setSubselectQuery(relationship, assertIsAccessible);
    }
	/**
	 * Add a subquery query to this query.  If a subquery for this relationship already exists, it will be returned.
	 * If not, a new one will be created and returned.
	 * @exception InvalidSubqueryRelationshipException If this method is called on a subselectQuery or with an invalid relationship 
	 * @param relationship The ChildRelationship to be added as a subquery
	**/
    private SOQLBuilder setSubselectQuery(ChildRelationship relationship, Boolean assertIsAccessible) {
        if (this.relationship != NULL) {
            throw new InvalidSubqueryRelationshipException(Label.ERR_INVALID_CALL_TO_SUBSELECT_QUERY_ADDITION);
        }
        if (this.subselectQueryMap == NULL) {
            this.subselectQueryMap = new Map<ChildRelationship, SOQLBuilder>();
        }
        if (this.subselectQueryMap.containsKey(relationship)) {
            return subselectQueryMap.get(relationship);
        }

        SOQLBuilder subselectQuery = new SOQLBuilder(relationship);

        //The child SOQLBuilder should be configured in the same way as the parent by default - can override after if required
        subSelectQuery.setSortSelectFields(sortSelectFields);

        if (assertIsAccessible) {
            subSelectQuery.assertIsAccessible();
        }
        subselectQueryMap.put(relationship, subSelectQuery);
        return subSelectQuery;
    }
	/**
	 * @returns the list of subquery instances of SOQLBuilder which will be added to the SOQL as relationship/child/sub-queries.
	**/
    public List<SOQLBuilder> getSubselectQueries() {
        if (subselectQueryMap != NULL) {
            return subselectQueryMap.values();
        }
        return NULL;
    }
	/**
	 * Get the ChildRelationship from the Table for the object type passed in.
	 * @param objType The object type of the child relationship to get
	**/
    private Schema.ChildRelationship getChildRelationship(sObjectType objType) {
        for (Schema.ChildRelationship childRow : table.getDescribe().getChildRelationships()) {
            //occasionally on some standard objects (Like Contact child of Contact) do not have a relationship name.
            //if there is no relationship name, we cannot query on it, so throw an exception.
            if (childRow.getChildSObject() == objType && childRow.getRelationshipName() != NULL) {
                return childRow;
            }
        }
        throw new InvalidSubqueryRelationshipException(Label.ERR_INVALID_CALL_TO_SUBSELECT_TABLE_RELATIONSHIP + table + ' and objtype=' + objType);
    }
	/**
	 * Get the ChildRelationship from the Table for the relationship name passed in.
	 * @param relationshipName The name of the object's ChildRelationship on get
	**/
    private Schema.ChildRelationship getChildRelationship(String relationshipName) {
        for (Schema.ChildRelationship childRow : table.getDescribe().getChildRelationships()) {
            if (childRow.getRelationshipName() == relationshipName) {
                return childRow;
            }
        }
        return NULL;
    }
	/**
	 * Add a field to be sorted on.  This may be a direct field or a field 
	 * related through an object lookup or master-detail relationship.
	 * Use the set to store unique field names, since we only want to sort
	 * by the same field one time.  The sort expressions are stored in a list
	 * so that they are applied to the SOQL in the same order that they
	 * were added in. 
	 * @param fieldName The string value of the field to be sorted on
	 * @param SortOrder the direction to be sorted on (ASCENDING or DESCENDING)
	 * @param nullsLast whether to sort null values last (NULLS LAST keyword included).
	**/
    public SOQLBuilder addOrdering(String fieldName, SortOrder direction, Boolean nullsLast) {
        order.add(new Ordering(getFieldToken(fieldName), direction, nullsLast));
        return this;
    }
     /**
	 * Add a field to be sorted on.  This may be a direct field or a field 
	 * related through an object lookup or master-detail relationship.
	 * Use the set to store unique field names, since we only want to sort
	 * by the same field one time.  The sort expressions are stored in a list
	 * so that they are applied to the SOQL in the same order that they
	 * were added in. 
	 * @param field The SObjectfield to sort.  This can only be a direct reference.
	 * @param SortOrder the direction to be sorted on (ASCENDING or DESCENDING)
	 * @param nullsLast whether to sort null values last (NULLS LAST keyword included).
	**/
    public SOQLBuilder addOrdering(SObjectField field, SortOrder direction, Boolean nullsLast) {
        order.add(new Ordering(new QueryField(field), direction, nullsLast));
        return this;
    }
    /**
	 * Add a field to be sorted on.  This may be a direct field or a field 
	 * related through an object lookup or master-detail relationship.
	 * Use the set to store unique field names, since we only want to sort
	 * by the same field one time.  The sort expressions are stored in a list
	 * so that they are applied to the SOQL in the same order that they
	 * were added in. 
	 * The "NULLS FIRST" keywords will be included by default.  If "NULLS LAST" 
	 * is required, use one of the overloaded addOrdering methods which include this parameter.
	 * @param fieldName The string value of the field to be sorted on
	 * @param SortOrder the direction to be sorted on (ASCENDING or DESCENDING)
	**/
    public SOQLBuilder addOrdering(String fieldName, SortOrder direction) {
        order.add(new Ordering(getFieldToken(fieldName), direction));
        return this;
    }
     /**
	 * Add a field to be sorted on.  This may be a direct field or a field 
	 * related through an object lookup or master-detail relationship.
	 * Use the set to store unique field names, since we only want to sort
	 * by the same field one time.  The sort expressions are stored in a list
	 * so that they are applied to the SOQL in the same order that they
	 * were added in. 
	 * The "NULLS FIRST" keywords will be included by default.  If "NULLS LAST" 
	 * is required, use one of the overloaded addOrdering methods which include this parameter.
	 * @param field The SObjectfield to sort.  This can only be a direct reference.
	 * @param SortOrder the direction to be sorted on (ASCENDING or DESCENDING)
	**/
    public SOQLBuilder addOrdering(SObjectField field, SortOrder direction) {
        order.add(new Ordering(new QueryField(field), direction));
        return this;
    }
	/**
	 * Convert the values provided to this instance into a full SOQL string for use with Database.query
	 * Check to see if subqueries queries need to be added after the field list.
	**/
    public String toSOQL() {
        String result = 'SELECT ';
        //if no fields have been added, just add the Id field so that the query or subquery will not just fail
        if (fields.size() == 0) {
            if (enforceFLS) {
                SFDCSecurityUtils.flsInspector.addFlsInspectionResult(SFDCSecurityUtils.checkFieldIsReadable(table, 'Id'));
            }
            SFDCSecurityUtils.flsInspector.checkResults();
            result += 'Id  ';
        }
        else if (sortSelectFields) {
            List<QueryField> fieldsToQuery = new List<QueryField>(fields);
            fieldsToQuery.sort(); //delegates to QueryFilter's comparable implementation
            for (QueryField field : fieldsToQuery) {
                result += field + ', ';
            }
        }
        else {
            for (QueryField field : fields) {
                result += field + ', ';
            }
        }

        if (subselectQueryMap != NULL && !subselectQueryMap.isEmpty()) {
            for (SOQLBuilder childRow : subselectQueryMap.values()) {
                result += ' (' + childRow.toSOQL() + '), ';
            }
        }
        result = result.substring(0, result.length() - 2) + ' FROM ' + (relationship != NULL ? relationship.getRelationshipName() : table.getDescribe().getName());
        if (conditionExpression != NULL) {
            result += ' WHERE ' + conditionExpression;
        }
        if (order.size() > 0) {
            result += ' ORDER BY ';
            for (Ordering o : order) {
                result += o.toSOQL() + ', ';
            }
            result = result.substring(0, result.length() - 2);
        }
        if (limitCount != NULL) {
            result += ' LIMIT ' + limitCount;
        }
        if (offset != NULL) {
            result += ' OFFSET ' + offset;
        }
        return result;
    }

	/**
	 * Create a "deep" clone of this object that can be safely mutated without affecting the cloned instance
	 * @return a deep clone of this SOQLBuilder
	**/
    public SOQLBuilder deepClone() {
        SOQLBuilder clone = new SOQLBuilder(this.table)
            .setLimit(this.limitCount)
            .setOffset(this.offset)
            .setCondition(this.conditionExpression)
            .setEnforceFLS(this.enforceFLS);

        Map<Schema.ChildRelationship, SOQLBuilder> subqueries = this.subselectQueryMap;
        if(subqueries != null) {
            Map<Schema.ChildRelationship, SOQLBuilder> clonedSubqueries = new Map<Schema.ChildRelationship, SOQLBuilder>();
            for(Schema.ChildRelationship key : subqueries.keySet()) {
                clonedSubqueries.put(key, subqueries.get(key).deepClone());
            }
            clone.subselectQueryMap = clonedSubqueries;
        }

        clone.relationship = this.relationship;
        clone.order = this.order.clone();
        clone.fields = this.fields.clone();

        return clone;
    }

    public static String buildDynamicSoqlQuery(
            List<String> fieldsToQuery,
            List<String> subQueryRelationshipNames,
            SObjectType sObjectType,
            String queryCondition,
            Boolean checkObjectIsAccessible,
            Boolean enforceFLS) {
        return buildDynamicSoqlQuery(
                fieldsToQuery,
                subQueryRelationshipNames,
                sObjectType,
                queryCondition,
                null,
                checkObjectIsAccessible,
                enforceFLS
        );
    }

    public static String buildDynamicSoqlQuery(
        List<String> fieldsToQuery,
        List<String> subQueryRelationshipNames,
        SObjectType sObjectType,
        String queryCondition,
        Integer limitNumber,
        Boolean checkObjectIsAccessible,
        Boolean enforceFLS) {

        String soql;
        if (checkObjectIsAccessible == NULL) {
            checkObjectIsAccessible = false;
        }

        if (enforceFLS == NULL) {
            enforceFLS = false;
        }

        if (fieldsToQuery != NULL && !fieldsToQuery.isEmpty() && sObjectType != NULL) {
            SOQLBuilder theQuery = new SOQLBuilder(sObjectType);
            if (checkObjectIsAccessible) {
                theQuery.assertIsAccessible();
            }
            theQuery
                .setEnforceFLS(enforceFLS)
                .selectFields(fieldsToQuery)
                .setCondition(queryCondition);
            if (limitNumber != null) {
                theQuery.setLimit(limitNumber);
            }
            //put subquery into main query
            if (subQueryRelationshipNames != NULL && !subQueryRelationshipNames.isEmpty()) {
                for (String subQueryRelationshipName : subQueryRelationshipNames) {
                    theQuery.subselectQuery(subQueryRelationshipName, true);
                }
            }
            soql = theQuery.toSOQL();
        }
        else {
            throw new QueryBuilderException(Label.ERR_UNABLE_TO_BUILD_SOQL);
        }

        return soql;
    }

    public List<SObject> getAccessDecisionResult(List<SObject> objs) {
        List<SObject> result = new List<SObject>();
        if (accessDecisionUtil != NULL) {
            accessDecisionUtil.setSObjects(objs);
            result = accessDecisionUtil.getRecords();
        }
        return result;
    }

    public Map<String, Set<String>> getAccessDecisionRemovedFields() {
        Map<String, Set<String>> result = new Map<String, Set<String>>();
        if (accessDecisionUtil != NULL && accessDecisionUtil.isAccessDecision()) {
            result = accessDecisionUtil.getRemovedFields();
        }
        return result;
    }

    public with sharing class Ordering {
        private SortOrder direction;
        private boolean nullsLast;
        private QueryField field;

        public Ordering(String sobjType, String fieldName, SortOrder direction) {
            this(SchemaDescribe.getDescribe(sobjType).getField(fieldName), direction);
        }
		/**
		 * Construct a new ordering instance for use with {@link SOQLBuilder#addOrdering}
		 * Once constructed it's properties may not be modified.
		**/
        public Ordering(Schema.SObjectField field, SortOrder direction) {
            this(field, direction, false); //SOQL docs state NULLS FIRST is default behavior
        }
        public Ordering(Schema.SObjectField field, SortOrder direction, Boolean nullsLast) {
            this(new QueryField(field), direction, nullsLast);
        }
        @TestVisible
        private Ordering(QueryField field, SortOrder direction) {
            this(field, direction, false);
        }
        @TestVisible
        private Ordering(QueryField field, SortOrder direction, Boolean nullsLast) {
            this.direction = direction;
            this.field = field;
            this.nullsLast = nullsLast;
        }
        public List<Schema.SObjectField> getFields() {
            return this.field.getFieldPath();
        }
        public SortOrder getDirection() {
            return direction;
        }
        public String toSOQL() {
            return field + ' ' + (direction == SortOrder.ASCENDING ? 'ASC' : 'DESC') + (nullsLast ? ' NULLS LAST ' : ' NULLS FIRST ');
        }
    }

    public with sharing class QueryField implements Comparable {
        List<Schema.SObjectField> fields;
		/**
		 * The full list of fields representing the path to the field being queried
		**/
        public List<SObjectField> getFieldPath() {
            return fields.clone();
        }
        @TestVisible
        private QueryField(List<Schema.SObjectField> fields) {
            if (fields == NULL || fields.size() == 0) {
                throw new InvalidFieldException(Label.ERR_INVALID_FIELD_NULL);
            }
            this.fields = fields.clone(); //don't let clients mutate after setting!
        }
        @TestVisible
        private QueryField(Schema.SObjectField field) {
            if (field == NULL) {
                throw new InvalidFieldException(Label.ERR_INVALID_FIELD_NULL);
            }
            fields = new List<Schema.SObjectField>{field};
        }

        public override String toString() {
            String result = '';
            Integer size = fields.size();
            for (Integer i=0; i < size; i++) {
                if (i > 0) {
                    if (result.endsWithIgnoreCase('Id')) {
                        result = result.removeEndIgnoreCase('Id');
                    }
                    else if (result.endsWithIgnoreCase('__c')) {
                        result = result.removeEndIgnoreCase('__c') + '__r';
                    }
                    result += '.';
                }
                result += fields[i].getDescribe().getName();
            }
            return result;
        }

        public Integer hashCode() {
            return String.valueOf(this.fields).hashCode();
        }

        public Boolean equals(Object obj) {
            //Easy checks first
            if (obj == NULL || !(obj instanceof QueryField)) {
                return false;
            }

            if (this === obj) {
                return true;
            }
            //Detailed checks
            QueryField other = (QueryField) obj;
            Integer size = fields.size();
            if (size != other.fields.size()) {
                return false;
            }

            for (Integer i = 0; i < size; i++) {
                if (fields[i] != (other.fields[i])) {
                    return false;
                }
            }
            return true;
        }
		/**
		 * Allows sorting QueryField instances.
		 *
		 * Returns:
		 * - Objects that are not QueryField instances as -2, which functions as -1 but with more flair
		 * - Equivalent QueryFields return 0.
		 * - QueryFields with more joins give +1, while fewer joins give -1
		 * - For anything else, compare the toStrings of this and the supplied object.
		 **/
        public Integer compareTo(Object o) {
            if (o == NULL || !(o instanceof QueryField)) {
                return -2; //We can't possibly do a sane comparison against an unknwon type, go athead and let it "win"
            }

            if (this === o) {
                return 0;
            }

            QueryField other = (QueryField) o;
            Integer size = fields.size();
            Integer sizeOther = other.fields.size();
            if (size < sizeOther) {
                return -1;
            }

            if (size > sizeOther) {
                return 1;
            }

            return this.toString().compareTo(other.toString());
        }
    }

    public class InvalidFieldException extends Exception {
        private String fieldName;
        private Schema.SObjectType objectType;
        public InvalidFieldException(String fieldname, Schema.SObjectType objectType) {
            this.objectType = objectType;
            this.fieldName = fieldName;
            this.setMessage(Label.ERR_INVALID_FIELD + fieldName + '\'' + Label.COMMON_FOR_OBJECT + objectType + '\'');
        }
    }

    public class InvalidFieldSetException extends Exception {}
    public class NonReferenceFieldException extends Exception {}
    public class InvalidSubqueryRelationshipException extends Exception {}
    public class QueryBuilderException extends Exception {}
    
}
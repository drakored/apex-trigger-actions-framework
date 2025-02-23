/*
   Copyright 2021 Google LLC

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

	https://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */

public inherited sharing class TriggerActionFlow implements TriggerAction.BeforeInsert, TriggerAction.AfterInsert, TriggerAction.BeforeUpdate, TriggerAction.AfterUpdate, TriggerAction.BeforeDelete, TriggerAction.AfterDelete, TriggerAction.AfterUndelete {
	public static final String APEX_STRING = 'Apex';
	public static final String FLOW_STRING = 'Flow';
	public static final String INVALID_BYPASS_REQUEST = 'You can only pass one request into {0}';
	public static final String INVALID_FLOW_NAME = 'You must provide the name of a flow to execute';
	public static final String INVALID_TYPE = 'The bypassType must equal Object, Apex, or Flow';
	public static final String OBJECT_STRING = 'Object';
	public static final String RECORD_PRIOR_VARIABLE = 'recordPrior';
	public static final String RECORD_VARIABLE = 'record';
	public static final Set<String> REQUEST_TYPES = new Set<String>{
		OBJECT_STRING,
		APEX_STRING,
		FLOW_STRING
	};
	@TestVisible
	private static Set<String> bypassedFlows = new Set<String>();
	private static Map<Schema.SObjectType, List<String>> sObjectToEditableFields = new Map<Schema.SObjectType, List<String>>();

	public String flowName;
	public Boolean allowRecursion;

	public static void bypass(String flowName) {
		TriggerActionFlow.bypassedFlows.add(flowName);
	}

	public static void clearBypass(String flowName) {
		TriggerActionFlow.bypassedFlows.remove(flowName);
	}

	public static Boolean isBypassed(String flowName) {
		return TriggerActionFlow.bypassedFlows.contains(flowName);
	}

	public static void clearAllBypasses() {
		TriggerActionFlow.bypassedFlows.clear();
	}

	public void beforeInsert(List<SObject> newList) {
		if (thisFlowIsBypassed()) {
			return;
		}
		Invocable.Action action = getAction();

		action.setInvocations(getInterviewInputs(newList, RECORD_VARIABLE));

		List<Invocable.Action.Result> results = action.invoke();

		handleInvocableResults(results, newList);

		applyFieldValuesDuringBefore(results, newList);
	}

	public void afterInsert(List<SObject> newList) {
		if (thisFlowIsBypassed()) {
			return;
		}
		Invocable.Action action = getAction();

		action.setInvocations(getInterviewInputs(newList, RECORD_VARIABLE));

		List<Invocable.Action.Result> results = action.invoke();

		handleInvocableResults(results, newList);
	}

	public void beforeUpdate(List<SObject> newList, List<SObject> oldList) {
		if (thisFlowIsBypassed()) {
			return;
		}
		List<sObject> recordsNotYetProcessed = new List<sObject>();
		List<sObject> oldRecordsNotYetProcessed = new List<sObject>();
		for (Integer i = 0; i < newList.size(); i++) {
			sObject record = newList[i];
			if (
				TriggerBase.idToNumberOfTimesSeenBeforeUpdate.get(record.id) == 1 ||
				(allowRecursion == true)
			) {
				recordsNotYetProcessed.add(record);
				oldRecordsNotYetProcessed.add(oldList[i]);
			}
		}
		Invocable.Action action = getAction();

		action.setInvocations(
			getInterviewInputs(recordsNotYetProcessed, oldRecordsNotYetProcessed)
		);

		List<Invocable.Action.Result> results = action.invoke();

		handleInvocableResults(results, recordsNotYetProcessed);

		applyFieldValuesDuringBefore(results, recordsNotYetProcessed);
	}

	public void afterUpdate(List<SObject> newList, List<SObject> oldList) {
		if (thisFlowIsBypassed()) {
			return;
		}
		List<sObject> recordsNotYetProcessed = new List<sObject>();
		List<sObject> oldRecordsNotYetProcessed = new List<sObject>();
		for (Integer i = 0; i < newList.size(); i++) {
			sObject record = newList[i];
			if (
				TriggerBase.idToNumberOfTimesSeenBeforeUpdate.get(record.id) == 1 ||
				(allowRecursion == true)
			) {
				recordsNotYetProcessed.add(record);
				oldRecordsNotYetProcessed.add(oldList[i]);
			}
		}
		Invocable.Action action = getAction();

		action.setInvocations(
			getInterviewInputs(recordsNotYetProcessed, oldRecordsNotYetProcessed)
		);

		List<Invocable.Action.Result> results = action.invoke();

		handleInvocableResults(results, recordsNotYetProcessed);
	}

	public void beforeDelete(List<SObject> oldList) {
		if (thisFlowIsBypassed()) {
			return;
		}
		Invocable.Action action = getAction();

		action.setInvocations(getInterviewInputs(oldList, RECORD_PRIOR_VARIABLE));

		List<Invocable.Action.Result> results = action.invoke();

		handleInvocableResults(results, oldList);
	}

	public void afterDelete(List<SObject> oldList) {
		if (thisFlowIsBypassed()) {
			return;
		}
		Invocable.Action action = getAction();

		action.setInvocations(getInterviewInputs(oldList, RECORD_PRIOR_VARIABLE));

		List<Invocable.Action.Result> results = action.invoke();

		handleInvocableResults(results, oldList);
	}

	public void afterUndelete(List<SObject> newList) {
		if (thisFlowIsBypassed()) {
			return;
		}
		Invocable.Action action = getAction();

		action.setInvocations(getInterviewInputs(newList, RECORD_VARIABLE));

		List<Invocable.Action.Result> results = action.invoke();

		handleInvocableResults(results, newList);
	}

	private Boolean thisFlowIsBypassed() {
		if (String.isBlank(flowName)) {
			throw new TriggerActionFlowException(INVALID_FLOW_NAME);
		}
		return TriggerActionFlow.isBypassed(flowName);
	}

	private Invocable.Action getAction() {
		return Invocable.Action.createCustomAction(FLOW_STRING, flowName);
	}

	private void applyFlowValues(
		sObject stateBeforeFlow,
		sObject stateAfterFlow,
		List<String> editableFields
	) {
		Map<String, Object> afterFlowMap = stateAfterFlow.getPopulatedFieldsAsMap();
		for (String fieldName : editableFields) {
			if (
				afterFlowMap.containsKey(fieldName) &&
				stateBeforeFlow.get(fieldName) != stateAfterFlow.get(fieldName)
			) {
				stateBeforeFlow.put(fieldName, stateAfterFlow.get(fieldName));
			}
		}
	}

	private List<Map<String, Object>> getInterviewInputs(
		List<SObject> newList,
		List<SObject> oldList
	) {
		List<Map<String, Object>> result = new List<Map<String, Object>>();
		for (Integer i = 0; i < newList.size(); i++) {
			SObject oldRecord = oldList[i];
			SObject newRecord = newList[i];
			result.add(
				new Map<String, Object>{
					RECORD_PRIOR_VARIABLE => oldRecord,
					RECORD_VARIABLE => newRecord
				}
			);
		}
		return result;
	}

	private List<Map<String, Object>> getInterviewInputs(
		List<SObject> records,
		String variableName
	) {
		List<Map<String, Object>> result = new List<Map<String, Object>>();
		for (Integer i = 0; i < records.size(); i++) {
			result.add(new Map<String, Object>{ variableName => records[i] });
		}
		return result;
	}

	private List<String> getEditableFields(
		Schema.SObjectType newRecordSObjectType
	) {
		if (sObjectToEditableFields.containsKey(newRecordSObjectType)) {
			return sObjectToEditableFields.get(newRecordSObjectType);
		}
		List<String> editableFields = new List<String>();
		for (
			Schema.SObjectField fieldRef : newRecordSObjectType
				.getDescribe()
				.fields.getMap()
				.values()
		) {
			Schema.DescribeFieldResult fieldResult = fieldRef.getDescribe();
			if (fieldResult.isUpdateable()) {
				editableFields.add(fieldResult.getName());
			}
		}
		sObjectToEditableFields.put(newRecordSObjectType, editableFields);
		return sObjectToEditableFields.get(newRecordSObjectType);
	}

	private void applyFieldValuesDuringBefore(
		List<Invocable.Action.Result> results,
		List<SObject> newList
	) {
		if (newList.isEmpty()) {
			return;
		}
		List<String> editableFields = getEditableFields(
			newList[0].getSObjectType()
		);
		for (Integer i = 0; i < results.size(); i++) {
			Invocable.Action.Result result = results[i];
			if (result.isSuccess() == true) {
				SObject newRecordWhenFlowIsComplete = (SObject) (result.getOutputParameters()
					.get(RECORD_VARIABLE));
				applyFlowValues(
					newList[i],
					newRecordWhenFlowIsComplete,
					editableFields
				);
			}
		}
	}

	private void handleInvocableResults(
		List<Invocable.Action.Result> results,
		List<SObject> records
	) {
		if (records.isEmpty()) {
			return;
		}
		for (Integer i = 0; i < results.size(); i++) {
			Invocable.Action.Result result = results[i];
			if (result.isSuccess() == false) {
				records[i].addError(getFormattedErrorMessage(result.getErrors()));
			}
		}
	}

	private String getFormattedErrorMessage(List<Invocable.Action.Error> errors) {
		List<String> messagesAndCodes = new List<String>();
		for (Invocable.Action.Error error : errors) {
			messagesAndCodes.add(error.getCode() + ' - ' + error.getMessage());
		}
		return String.join(messagesAndCodes, ', ');
	}

	@TestVisible
	private class TriggerActionFlowException extends Exception {
	}
}

import * as util from "util";

import {
    ApplicationModelOptions,
    IApplicationModel,
    IEnvironment,
    IHashMap,
    IStateEntity,
    IStatusEntity,
    StatusEvent,
} from "./typings";

import { HashMap } from "./hashMap";
import { Logger } from "./logger";
import { Resource } from "./resource";
import { StateEntity } from "./stateEntity";
import { StatusEntity } from "./statusEntity";
import { StatusTarget } from "./statusTarget";
import { Utils } from "./utils";

type DeletionTarget = {
    reason: string;
    instanceId: string;
};

class ApplicationModel implements IApplicationModel {
    public static async createInstance(
        environment: IEnvironment, options?: ApplicationModelOptions): Promise<IApplicationModel> {
        return Logger.enterAsync<ApplicationModel>("ApplicationModel.createInstance", async () => {
            // create model instance
            const model = new ApplicationModel(environment, options);
            // init model
            await model.initialize();
            // all done
            return model;
        });
    }

    public environment: IEnvironment;
    private options: ApplicationModelOptions;

    constructor(environment: IEnvironment, options: ApplicationModelOptions) {
        Logger.enter("ApplicationModel.constructor", () => {
            this.options = options;
            this.environment = environment;
        });
    }

    public async state(): Promise<void> {
        return Logger.enterAsync("ApplicationModel.state", async () => {
            // get ready state
            const isReady = await this.isReady();
            // check if ready
            if (isReady) {
                // clean states first
                await this.cleanStates();
                // loop over all targets
                for (const target of StatusTarget.targets) {
                    // check if supported target type
                    switch (target.type) {
                        case "VirtualMachineScaleSet":
                            if (target.resources !== undefined && target.resources !== null) {
                                // loop over all resources found in the target
                                for (const resource of target.resources) {
                                    // update state of the one found
                                    await this.updateVmssState(resource);
                                }
                            }
                            break;
                    }
                }
            }
        });
    }

    public async status(): Promise<void> {
        return Logger.enterAsync("ApplicationModel.status", async () => {
            // get ready state
            const isReady = await this.isReady();
            // check if ready
            if (isReady) {
                // clean statuses first
                await this.cleanStatuses();
                // check status overview
                await this.checkStatus();
            }
        });
    }

    public async event(event: StatusEvent): Promise<void> {
        return Logger.enterAsync("ApplicationModel.event", async () => {
            // get ready state
            const isReady = await this.isReady();
            // check if ready
            if (isReady) {
                if (event.topic.toLowerCase() === this.options.topicId.toLowerCase()) {
                    switch (event.eventType.toLowerCase()) {
                        case "mercator-status":
                            // see if we can find the target
                            const target = StatusTarget.getByResourceId(event.subject);
                            // check if found or ingnore
                            if (target !== null) {
                                // update the status
                                await this.updateStatus(
                                    event.subject, event.data.type, event.data.name,
                                    event.data.category, event.data.status, event.data.data);
                            }
                            break;
                    }
                }
            }
        });
    }

    private async initialize(): Promise<void> {
        return Logger.enterAsync<void>("ApplicationModel.initialize", async () => {
            // mark as ready
            await this.markReady();
        });
    }

    private async isReady(): Promise<boolean> {
        return Logger.enterAsync<boolean>("ApplicationModel.isReady", async () => {
            return await this.environment.data.isReadyState("application-model-system-state");
        });
    }

    private async markReady(): Promise<void> {
        return Logger.enterAsync<void>("ApplicationModel.markReady", async () => {
            await this.environment.data.markReadyState("application-model-system-state");
        });
    }

    private mapVirtualMachines(
        vms: any[], subscriptionId: string, resourceGroup: string, virtualMachineScaleSet: string): IHashMap {
        return Logger.enter<IHashMap>("ApplicationModel.mapVirtualMachines", () => {
            const map = new HashMap();
            for (const vm of vms) {
                if (map.has(subscriptionId) === false) {
                    map.set(subscriptionId, new HashMap());
                }
                if (map.get(subscriptionId).has(resourceGroup) === false) {
                    map.get(subscriptionId).set(resourceGroup, new HashMap());
                }
                if (map.get(subscriptionId).get(resourceGroup).has(virtualMachineScaleSet) === false) {
                    map.get(subscriptionId).get(resourceGroup).set(virtualMachineScaleSet, new HashMap());
                }
                if (map.get(subscriptionId).get(resourceGroup).get(virtualMachineScaleSet)
                    .has(vm.instanceId) === false) {
                    map.get(subscriptionId).get(resourceGroup).get(virtualMachineScaleSet)
                        .set(vm.instanceId, vm);
                }
            }
            return map;
        });
    }

    private async cleanStates(): Promise<void> {
        return Logger.enterAsync<void>("ApplicationModel.cleanStates", async () => {
            // the deletes to do
            const deletes: IStateEntity[] = [];
            // get all entities
            const states = await this.environment.data.readStates();
            // loop over each
            for (const state of states) {
                // check if found in target
                const target = StatusTarget.getByResourceId(state.id);
                // if not found delete it
                if (target === null) {
                    deletes.push(state);
                }
            }
            // see if any deletes to do
            if (deletes.length > 0) {
                await this.environment.data.deleteStates(deletes);
            }
        });
    }

    private async cleanStatuses(): Promise<void> {
        return Logger.enterAsync<void>("ApplicationModel.cleanStatuses", async () => {
            // the deletes to do
            const deletes: IStatusEntity[] = [];
            // get all entities
            const statuses = await this.environment.data.readStatuses();
            // loop over each
            for (const status of statuses) {
                // check if found in target
                const target = StatusTarget.getByResourceId(status.id);
                // if not found delete it
                if (target === null) {
                    deletes.push(status);
                }
            }
            // see if any deletes to do
            if (deletes.length > 0) {
                await this.environment.data.deleteStatuses(deletes);
            }
        });
    }

    private async deleteVmssMachines(id: string, targets: DeletionTarget[]): Promise<void> {
        return Logger.enterAsync("ApplicationModel.deleteVmssMachines", async () => {
            // notify
            this.environment.logger.warn("deleting one or more machines from scaleset with id: " + id);
            this.environment.logger.warn("deleting targets: " + JSON.stringify(targets));
            // wrap in managed resource
            const resource = new Resource(id);
            // delete the machine
            await this.environment.api.compute.virtualMachineScaleSets.deleteVirtualMachines(
                resource.resourceGroup, resource.name, targets.map((target) => {
                    return target.instanceId;
                }));
            // notify
            this.environment.logger.warn("targets deleted: " + JSON.stringify(targets));
        });
    }

    private async updateVmssState(id: string): Promise<void> {
        return Logger.enterAsync("ApplicationModel.updateVmssState", async () => {
            // see if anything to check for
            if (id !== undefined && id !== null && id !== "") {
                // the crud
                const creates: IStateEntity[] = [];
                const updates: IStateEntity[] = [];
                const deletes: IStateEntity[] = [];
                const failures: DeletionTarget[] = [];
                // create the native resource
                const resource = new Resource(id);
                // map them accordinly for easier traversal
                const stateMap = await this.environment.data.fetchStateMap();
                // get all virtual machines
                const vmList: any[] = await this.environment.api.compute.virtualMachineScaleSets.listVirtualMachines(
                    resource.resourceGroup, resource.name);
                // map virtual machines provided
                const vmMap = this.mapVirtualMachines(
                    vmList, resource.subscriptionId, resource.resourceGroup, resource.name);
                // let"s do deletes & updates first
                stateMap.each((subKey: any, subValue: any) => {
                    subValue.each((rgKey: string, rgValue: any) => {
                        rgValue.each((nameKey: string, nameValue: any) => {
                            nameValue.each((tagKey: string, state: IStateEntity) => {
                                if (state.id === id) {
                                    if (vmMap.has(subKey) &&
                                        vmMap.get(subKey).has(rgKey) &&
                                        vmMap.get(subKey).get(rgKey).has(nameKey) &&
                                        vmMap.get(subKey).get(rgKey).get(nameKey).has(state.tag)) {
                                        // get associated vm
                                        const vm = vmMap.get(subKey).get(rgKey).get(nameKey).get(state.tag);
                                        // handle updates
                                        if (state.state !== vm.provisioningState) {
                                            // save new state
                                            state.state = vm.provisioningState;
                                            // update state
                                            updates.push(state);
                                            // check special case
                                            if (vm.provisioningState === "Failed") {
                                                failures.push({
                                                    instanceId: state.tag,
                                                    reason: "ProvisioningState Failed",
                                                });
                                            }
                                        }
                                    } else {
                                        // handle deletes
                                        deletes.push(state);
                                    }
                                }
                            });
                        });
                    });
                });
                // handle creates
                vmList.forEach((vm) => {
                    // check if state does already exists or not
                    if (!stateMap.has(resource.subscriptionId) ||
                        !stateMap.get(resource.subscriptionId).has(resource.resourceGroup) ||
                        !stateMap.get(resource.subscriptionId).get(resource.resourceGroup).has(resource.name) ||
                        !stateMap.get(resource.subscriptionId).
                            get(resource.resourceGroup).get(resource.name).has(vm.instanceId)) {
                        // create new state
                        creates.push(new StateEntity(
                            id,
                            "VirtualMachineScaleSet",
                            vm.instanceId,
                            new Date(),
                            vm.provisioningState,
                        ));
                    }
                });
                // calls to make
                const calls = [];
                // check what to crud
                if (creates.length > 0) {
                    this.environment.logger.info(
                        util.format("number of creates found for %s: %s", id, creates.length));
                    calls.push(this.environment.data.createStates(creates));
                }
                if (updates.length > 0) {
                    this.environment.logger.info(
                        util.format("number of updates found for %s: %s", id, updates.length));
                    calls.push(this.environment.data.updateStates(updates));
                }
                if (deletes.length > 0) {
                    this.environment.logger.info(
                        util.format("number of deletes found for %s: %s", id, deletes.length));
                    calls.push(this.environment.data.deleteStates(deletes));
                }
                // process crud if needed
                if (calls.length > 0) {
                    // do the  calls
                    await Promise.all(calls);
                }
                // delete the failed ones if needed
                if (failures.length > 0) {
                    await this.deleteVmssMachines(id, failures);
                }
            }
        });
    }

    private async updateStatus(
        id: string, type: string, tag: string, category: string, status: string, data: any): Promise<void> {
        return Logger.enterAsync("ApplicationModel.updateStatus", async () => {
            // get current status
            const current: IStatusEntity = await this.environment.data.readStatus(id, type, tag);
            // see if valid and status has changed
            if (current !== null) {
                if (current.status !== status) {
                    // update
                    await this.environment.data.upsertStatus(new StatusEntity(
                        id, type, tag, category, new Date(), status, data,
                    ));
                } else {
                    // update as found but timestamp needs updating
                    await this.environment.data.upsertStatus(new StatusEntity(
                        id, type, tag, category, current.changedWhen, status, data,
                    ));
                }
            } else {
                // update as not found
                await this.environment.data.upsertStatus(new StatusEntity(
                    id, type, tag, category, new Date(), status, data,
                ));
            }
        });
    }

    private async checkStatus(): Promise<void> {
        return Logger.enterAsync("ApplicationModel.checkStatus", async () => {
            // get both maps
            const results = await Promise.all([
                this.environment.data.fetchStateMap(),
                this.environment.data.fetchStatusMap(),
            ]);
            // final calls to be made
            const calls = [];
            // get state map
            const stateMap: IHashMap = results[0];
            // get status map
            const statusMap: IHashMap = results[1];
            // deletes to do
            const deletes: IHashMap = new HashMap();
            // loop over each of them
            statusMap.each((subKey: any, subValue: any) => {
                subValue.each((rgKey: string, rgValue: any) => {
                    rgValue.each((typeKey: string, typeValue: any) => {
                        typeValue.each((tagKey: string, status: IStatusEntity) => {
                            // calculate instance id
                            const instanceId = Utils.hostNameToInstanceId(status.tag).toString();
                            // look up in state map
                            if (stateMap.has(subKey) &&
                                stateMap.get(subKey).has(rgKey) &&
                                stateMap.get(subKey).get(rgKey).has(typeKey) &&
                                stateMap.get(subKey).get(rgKey).get(typeKey).has(instanceId)) {
                                // get instance
                                const instance = stateMap.get(subKey).get(rgKey).get(typeKey).get(instanceId);
                                // look up if its in status target
                                const statusTarget = StatusTarget.getByResourceId(instance.id);
                                // if found handle it
                                if (statusTarget !== null) {
                                    // set proper reason
                                    let reason = "ProvisioningState Failed";
                                    // mark for deletion if state is failed
                                    let doDelete = instance.state === "Failed";
                                    // check for grace period setting
                                    if (!doDelete && statusTarget.grace > 0) {
                                        // don"t do anything if not paased grace period
                                        if (instance.createdWhen.getTime() +
                                            (statusTarget.grace * 1000) <= Date.now()) {
                                            return;
                                        }
                                    }
                                    // check if in right provisioning state
                                    if (!doDelete && instance.state === "Succeeded") {
                                        // set proper reason
                                        reason = doDelete ? reason : "Service Health Down";
                                        // check if not state change is down and not changed for specified period
                                        doDelete = doDelete || (
                                            (status.changedWhen.getTime() +
                                                (statusTarget.expiration * 1000)) <= Date.now() &&
                                            status.status === statusTarget.unhealthy);
                                        // set proper reason
                                        reason = doDelete ? reason : "Service Health Expired";
                                        // check if not expired all together
                                        doDelete = doDelete ||
                                            (status.timestamp.getTime() +
                                                (statusTarget.expiration * 1000)) <= Date.now();
                                    }
                                    // check if actual deletion is reauired
                                    if (doDelete) {
                                        // make sure array is there
                                        if (!deletes.has(status.id)) {
                                            deletes.set(status.id, []);
                                        }
                                        // add entity to be deleted
                                        deletes.get(status.id).push({
                                            entity: status,
                                            reason,
                                        });
                                    }
                                }
                            } else {
                                // clean up by deleting entity
                                calls.push(this.environment.data.deleteStatuses([status]));
                            }
                        });
                    });
                });
            });
            // check frontends
            if (deletes.size() > 0) {
                // loop over deletes and handle accordingly
                deletes.each((key: string, targets: any[]) => {
                    // delete entity
                    calls.push(this.environment.data.deleteStatuses(targets.map((target) => {
                        return target.entity;
                    })));
                    // delete the machine using host name to instance id translation
                    calls.push(this.deleteVmssMachines(key,
                        targets.map((target: any) => {
                            return {
                                instanceId: Utils.hostNameToInstanceId(target.entity.tag).toString(),
                                reason: target.reason,
                            };
                        })));
                });
            }
            // check if any calls are pending
            if (calls.length > 0) {
                await Promise.all(calls);
            }
        });
    }
}

// export
export { StatusTarget };
export { ApplicationModel };

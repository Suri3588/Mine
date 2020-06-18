const { exec } = require('child_process');
const util  = require('util');

const RG = process.argv[2];
const showDeployments = process.argv[3];
if(!RG) {
    console.log(`Resource group is mandatory`);
    process.exit(1);
}
const small_box = `
+-------------------------------------------------------------------------+
|                                                                         |
|                                                                         |
|text_here|
|sub_title|
|memory|
|cpu|
|disk|
|                                                                         |
deployments
|                                                                         |
|                                                                         |
|                                                                         |
+-------------------------------------------------------------------------+

`;

const box_size = small_box.split('\n')[1].length - 2;// Fist line is empty.

const service = `
+---------------------------------+
|name|
|memory|
|cpu|
+---------------------------------+
`;

const pad = (str = "", size) => str.padStart(size/2).padEnd(size)
const groupBy = (xs, key) => xs.reduce((rv, x) =>{
    const value = typeof key == 'function' ? key(x) :  get(x, key);
    (rv[value] = rv[value] || []).push(x);
    return rv;
}, {});

const get = (obj, key, dv) => obj && key.split('.').reduce((current, key)=> current && current[key], obj) || dv;

const map = (objs, fn) => Object.keys(objs).map(key => fn(objs[key], key));

const addDeploymentBox = (deployment) => {
    const n_services = parseInt(deployment.spec.replicas);
    const memory_max = `${parseInt(get(deployment,'spec.template.spec.containers.0.resources.limits.memory', 0)) * n_services} GB`;
    const memory_min = `${get(deployment,'spec.template.spec.containers.0.resources.limits.memory', 0)} GB`;
    const cpu_max = `${parseInt(get(deployment,'spec.template.spec.containers.0.resources.limits.cpu', 0)) * n_services} CPU`;
    const cpu_min = `${get(deployment,'spec.template.spec.containers.0.resources.limits.cpu', 0)} CPU`;
    deployment.box = service
        .replace('name', pad(`${deployment.metadata.name} (${n_services})`, 33))
        .replace('cpu', pad(`Max: ${cpu_max} / Each: ${cpu_min}`, 33))
        .replace('memory', pad(`Max: ${memory_max} / Each: ${memory_min}`, 33))
    return deployment;
}

const execAsync = util.promisify(exec);
const execAsPromise = async (command) => {
      const { stdout  } = await execAsync(command, { maxBuffer: 1024 * 50000 });
      return JSON.parse(stdout)
};

function groupByPair(data) {
    let n = 1;
    return groupBy(data, () => {
        n++;
        return parseInt(n / 2);
    });
}

function joinTextLineByLine(textList, linePad = 0) {
    return !textList.length ? "" : textList.reduce((current, accumulated) => {
        const larger = current.length > accumulated.length ? current : accumulated;
        return larger.map((line, n) => {
            return `${pad(current[n]||'', linePad)}   ${accumulated[n]||''}`;
        });
    })
}

async function run() {
    const [nodesQuery, azureMachines] = await Promise.all([execAsPromise('kubectl get nodes -o json'), execAsPromise(`az vm list --resource-group ${RG} -o json`)]);
    const nodes = nodesQuery.items;

    const deploymentsQuery = await execAsPromise('kubectl get deployments -A -o json');
    const deployments = deploymentsQuery.items;
    deployments.forEach(deployment => {
        deployment.agentpool = get(deployment, 'spec.template.spec.nodeSelector.agentpool', 'any');
    });

    const groupedDeployments = groupBy(deployments, 'agentpool');

    nodes.forEach(node => {
        node.node_name = get(node, 'metadata.labels.agentpool');
    });
    const groupedNodes = groupBy(nodes, 'metadata.labels.agentpool');
    if(showDeployments) {
        groupedNodes['any'] = [{
            sub_title: "Not a real Virtual machine!"
        }];
    }

    const azureBoxes = map(azureMachines, azureNode => {
        azureNode.box = small_box
            .replace('text_here', pad(`${azureNode.name} `, box_size))
            .replace('sub_title', pad(`${get(azureNode, 'hardwareProfile.vmSize', '')}`, box_size))
            .replace('memory', pad("", box_size))
            .replace('cpu', pad("",box_size))
            .replace('deployments', `|${pad("",box_size)}|`)
            .replace('disk', pad(azureNode.storageProfile.dataDisks.reduce((str, disk) => str + `${disk.name}: ${disk.diskSizeGb}GB, `, ''), box_size));
        return azureNode.box;
    });

    const boxes = map(groupedNodes, (nodes, node_name) => {
        // Nodes
        const node = nodes[0];
        node.box = small_box
            .replace('text_here', pad(`${node_name} (${nodes.length}) `, box_size))
            .replace('sub_title',pad(`${node.sub_title||get(nodes, '0.metadata.labels', {})['beta.kubernetes.io/instance-type']}`, box_size))
            .replace('memory', pad(node.status && get(nodes, '0.status.capacity.memory') && `${nodes.length * (parseInt(parseInt(nodes[0].status.capacity.memory)/1024/1024)+1)} GB`, box_size))
            .replace('cpu', pad(node.status && nodes[0].status.capacity && `${nodes.length * parseInt(nodes[0].status.capacity.cpu)} CPU`, box_size))
            .replace('disk', pad('', box_size));


        // Deployment
        const deployments = groupedDeployments[node_name];
        deployments.forEach(addDeploymentBox);


        //Final Box
        let n = 1;
        const deployments_group = groupByPair(deployments);
        const final_text = map(deployments_group, deployments => {
            const services_boxes = map(deployments, d => d.box).map(s => s.split("\n"));
            const text = !services_boxes.length ? "" : joinTextLineByLine(services_boxes).map(str => `|${pad(str, box_size)}|`)
            .join('\n');
            return text;
        }).join('\n');
        if(showDeployments) {
            node.box = node.box.replace('deployments', final_text);
        } else {
            node.box = node.box.replace('deployments', `|${pad('', box_size)}|`);
        }
        return node.box;
    });
    const boxGroups = map(groupByPair(boxes.concat(azureBoxes)), boxes => joinTextLineByLine(boxes.map(a => a.split("\n")), 75).join("\n"));
    boxGroups.forEach(box => console.log(box));
}

run();

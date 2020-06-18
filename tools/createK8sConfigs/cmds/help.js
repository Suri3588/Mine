const menus = {
  main: `
    createK8sConfigs [command] <options>

    help ......................... get help
    full ......................... equicvalent to running k8s followed by process
    k8s .......................... generate kubernetes configs from a process_all_separate,json file
    process ...................... process the k8s templates
    terraform .................... create terraform configuration
    version ...................... get version
    
    General options:
        --help, -h ............... show help menu for a command
        --version, -v ............ show package version`,

  full: `
    createK8sConfig full --procfile <process_all_separate_file> --envconf <environment_config_file< --repodir <KNucleus_directory> --renderj2 <path_to_renderJ2File.py> [--execute]
    
    process_all_separate_file ...... path to the process_all_separate.json file generated by Build 2.X
    environment_config_file ........ path to the json file holding teh environment config
    KNucleus_directory ............. root directory of the local KNucleus-cs clone
    path_to_renderJ2File.py ........ path to the template render script
    execute ........................ run the process`,

  help: `
    createK8sConfigs help [command]
    
    Same as --help, -h`,

  k8s: `
    createK8sConfig k8s --procfile <process_all_separate_file> --repodir <KNucleus_directory>
    
    process_all_separate_file ...... path to the process_all_separate.json file generated by Build 2.X
    KNucleus_directory ............. root directory of the local KNucleus-cs clone`,

  process: `
    createK8sConfig process --envconf <environment_config_file> --repodir <KNucleus_directory> --renderj2 <path_to_renderJ2File.py> [--execute]
    
    environment_config_file ........ path to the json file holding teh environment config
    KNucleus_directory ............. root directory of the local KNucleus-cs clone
    path_to_renderJ2File.py ........ path to the template render script
    execute ........................ run the process`,

  terraform: `
    createK8sConfig terraform --envconf <environment_config_file< --terraformdir <terrafrom_directory> --renderj2 <path_to_renderJ2File.py>
    
    environment_config_file ........ path to the json file holding the environment config
    terraform_directory ............ directory containing the terraform configuration for the deployment
    path_to_renderJ2File.py ........ path to the template render script`,

  version: `
    createK8sConfigs version
    
    same as --version, -v`

}

module.exports = (args) => {
  const sub = (args._[0] === 'help') ? args._[1] : args._[0];
  console.log(menus[sub] || menus.main);
}
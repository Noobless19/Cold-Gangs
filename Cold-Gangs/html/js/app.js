const app = new Vue({
    el: '#app',
    data: {
        visible: false,
        currentTab: 'dashboard',
        gang: {
            id: 0,
            name: '',
            tag: '',
            rank: 1,
            isLeader: false,
            bank: 0,
            reputation: 0,
            color: '#ff3e3e',
            logo: null
        },
        members: [],
        territories: [],
        businesses: [],
        drugs: {
            fields: [],
            labs: []
        },
        wars: [],
        heists: [],
        vehicles: [],
        stashes: {
            main: null,
            shared: {}
        },
        recentActivities: [],
        availableGangs: [],
        businessUpgradeOptions: {},
        config: {},
        showModal: false,
        modalType: '',
        modalTitle: '',
        modalData: {},
        settings: {
            name: '',
            tag: '',
            color: '#ff3e3e',
            logo: '',
            newLeader: '',
            maxMembers: 25
        }
    },
    computed: {
        onlineMembers() {
            return this.members.filter(member => member.isOnline);
        }
    },
    mounted() {
        window.addEventListener('message', this.onMessage);
        this.notifyReady();
    },
    beforeDestroy() {
        window.removeEventListener('message', this.onMessage);
    },
    methods: {
        // Core functions
        onMessage(event) {
            const data = event.data;
            
            if (data.action === 'openDashboard') {
                this.gang = data.gang;
                this.config = data.config;
                this.visible = true;
                this.loadDashboardData();
            } else if (data.action === 'updateGangData') {
                this.gang = data.gang;
            }
        },
        
        notifyReady() {
            fetch('https://cold-gangs/nuiReady', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            });
        },
        
        closeUI() {
            this.visible = false;
            fetch('https://cold-gangs/closeUI', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            });
        },
        
        setTab(tab) {
            this.currentTab = tab;
            
            // Load data based on tab
            switch(tab) {
                case 'dashboard':
                    this.loadDashboardData();
                    break;
                case 'members':
                    this.loadMembers();
                    break;
                case 'territories':
                    this.loadTerritories();
                    break;
                case 'businesses':
                    this.loadBusinesses();
                    break;
                case 'drugs':
                    this.loadDrugs();
                    break;
                case 'wars':
                    this.loadWars();
                    break;
                case 'heists':
                    this.loadHeists();
                    break;
                case 'vehicles':
                    this.loadVehicles();
                    break;
                case 'stashes':
                    this.loadStashes();
                    break;
                case 'bank':
                    this.loadBankData();
                    break;
                case 'settings':
                    this.loadSettings();
                    break;
            }
        },
        
        // Data loading functions
        loadDashboardData() {
            this.loadMembers();
            this.loadTerritories();
            this.loadRecentActivities();
        },
        
        loadMembers() {
            fetch('https://cold-gangs/getMembers', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.members = data.data;
                }
            });
        },
        
        loadTerritories() {
            fetch('https://cold-gangs/getTerritories', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.territories = data.data;
                }
            });
        },
        
        loadBusinesses() {
            fetch('https://cold-gangs/getBusinesses', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.businesses = data.data;
                }
            });
        },
        
        loadDrugs() {
            fetch('https://cold-gangs/getDrugs', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.drugs = data.data;
                }
            });
        },
        
        loadWars() {
            fetch('https://cold-gangs/getWars', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.wars = data.data;
                }
            });
        },
        
        loadHeists() {
            fetch('https://cold-gangs/getHeists', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.heists = data.data;
                }
            });
        },
        
        loadVehicles() {
            fetch('https://cold-gangs/getVehicles', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.vehicles = data.data;
                }
            });
        },
        
        loadStashes() {
            fetch('https://cold-gangs/getStashes', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.stashes = data.data;
                }
            });
        },
        
        loadBankData() {
            this.loadRecentActivities();
        },
        
        loadRecentActivities() {
            fetch('https://cold-gangs/getRecentActivities', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.recentActivities = data.data;
                }
            });
        },
        
        loadSettings() {
            this.settings.name = this.gang.name;
            this.settings.tag = this.gang.tag;
            this.settings.color = this.gang.color || '#ff3e3e';
            this.settings.logo = this.gang.logo || '';
            this.settings.maxMembers = this.gang.maxMembers || 25;
        },
        
        loadAvailableGangs() {
            fetch('https://cold-gangs/getAvailableGangs', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.availableGangs = data.data;
                }
            });
        },
        
        loadBusinessUpgradeOptions(businessId) {
            fetch('https://cold-gangs/getBusinessUpgradeOptions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ businessId })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    this.businessUpgradeOptions = data.data;
                }
            });
        },
        
        // Member management
        inviteMember() {
            fetch('https://cold-gangs/inviteMember', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            });
        },
        
        promoteMember(member) {
            fetch('https://cold-gangs/promoteMember', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ citizenId: member.citizenId })
            });
        },
        
        demoteMember(member) {
            fetch('https://cold-gangs/demoteMember', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ citizenId: member.citizenId })
            });
        },
        
        kickMember(member) {
            this.showModal = true;
            this.modalType = 'kickMember';
            this.modalTitle = 'Kick Member';
            this.modalData = {
                citizenId: member.citizenId,
                name: member.name,
                reason: ''
            };
        },
        
        // Territory management
        viewTerritory(territory) {
            fetch('https://cold-gangs/viewTerritory', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ territoryName: territory.name })
            });
        },
        
        abandonTerritory(territory) {
            fetch('https://cold-gangs/abandonTerritory', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ territoryName: territory.name })
            });
        },
        
        // Business management
        showCreateBusinessModal() {
            this.showModal = true;
            this.modalType = 'createBusiness';
            this.modalTitle = 'Create Business';
            this.modalData = {
                businessType: ''
            };
        },
        
        showUpgradeBusinessModal(business) {
            this.loadBusinessUpgradeOptions(business.id);
            this.showModal = true;
            this.modalType = 'upgradeBusiness';
            this.modalTitle = 'Upgrade Business';
            this.modalData = {
                businessId: business.id,
                upgradeType: ''
            };
        },
        
        manageBusiness(business) {
            fetch('https://cold-gangs/manageBusiness', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ businessId: business.id })
            });
        },
        
        collectBusinessIncome(business) {
            fetch('https://cold-gangs/collectBusinessIncome', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ businessId: business.id })
            });
        },
        
        // Drug management
        viewField(field) {
            fetch('https://cold-gangs/viewField', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ fieldId: field.id })
            });
        },
        
        harvestField(field) {
            fetch('https://cold-gangs/harvestField', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ fieldId: field.id })
            });
        },
        
        processDrugs(lab) {
            fetch('https://cold-gangs/processDrugs', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ labId: lab.id })
            });
        },
        
        upgradeLab(lab) {
            fetch('https://cold-gangs/upgradeLab', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ labId: lab.id })
            });
        },
        
        // War management
        showDeclareWarModal() {
            this.loadAvailableGangs();
            this.showModal = true;
            this.modalType = 'declareWar';
            this.modalTitle = 'Declare War';
            this.modalData = {
                targetGangId: ''
            };
        },
        
        viewWar(war) {
            fetch('https://cold-gangs/viewWar', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ warId: war.id })
            });
        },
        
        surrenderWar(war) {
            fetch('https://cold-gangs/surrenderWar', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ warId: war.id })
            });
        },
        
        // Heist management
        showPlanHeistModal() {
            this.showModal = true;
            this.modalType = 'planHeist';
            this.modalTitle = 'Plan Heist';
            this.modalData = {
                heistType: ''
            };
        },
        
        viewHeist(heist) {
            fetch('https://cold-gangs/viewHeist', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ heistId: heist.id })
            });
        },
        
        joinHeist(heist) {
            fetch('https://cold-gangs/joinHeist', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ heistId: heist.id })
            });
        },
        
        cancelHeist(heist) {
            fetch('https://cold-gangs/cancelHeist', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ heistId: heist.id })
            });
        },
        
        // Vehicle management
        registerVehicle() {
            fetch('https://cold-gangs/registerVehicle', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            });
        },
        
        spawnVehicle(vehicle) {
            fetch('https://cold-gangs/spawnVehicle', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ plate: vehicle.plate })
            });
        },
        
        storeVehicle(vehicle) {
            fetch('https://cold-gangs/storeVehicle', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ plate: vehicle.plate })
            });
        },
        
        trackVehicle(vehicle) {
            fetch('https://cold-gangs/trackVehicle', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ plate: vehicle.plate })
            });
        },
        
        // Stash management
        showCreateStashModal() {
            this.showModal = true;
            this.modalType = 'createStash';
            this.modalTitle = 'Create Stash';
            this.modalData = {
                name: '',
                minRank: 1
            };
        },
        
        openStash(stashId) {
            fetch('https://cold-gangs/openStash', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ stashId })
            });
        },
        
        deleteStash(stashId) {
            fetch('https://cold-gangs/deleteStash', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ stashId })
            });
        },
        
        // Bank management
        showDepositModal() {
            this.showModal = true;
            this.modalType = 'deposit';
            this.modalTitle = 'Deposit Money';
            this.modalData = {
                amount: 0
            };
        },
        
        showWithdrawModal() {
            this.showModal = true;
            this.modalType = 'withdraw';
            this.modalTitle = 'Withdraw Money';
            this.modalData = {
                amount: 0
            };
        },
        
        showTransferModal() {
            this.loadAvailableGangs();
            this.showModal = true;
            this.modalType = 'transfer';
            this.modalTitle = 'Transfer Money';
            this.modalData = {
                targetGangId: '',
                amount: 0,
                reason: ''
            };
        },
        
        // Settings management
        changeGangName() {
            fetch('https://cold-gangs/changeGangName', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ name: this.settings.name })
            });
        },
        
        changeGangTag() {
            fetch('https://cold-gangs/changeGangTag', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ tag: this.settings.tag })
            });
        },
        
        changeGangColor() {
            fetch('https://cold-gangs/changeGangColor', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ color: this.settings.color })
            });
        },
        
        changeGangLogo() {
            fetch('https://cold-gangs/changeGangLogo', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ logo: this.settings.logo })
            });
        },
        
        transferLeadership() {
            fetch('https://cold-gangs/transferLeadership', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ targetCitizenId: this.settings.newLeader })
            });
        },
        
        setMaxMembers() {
            fetch('https://cold-gangs/setMaxMembers', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ maxMembers: this.settings.maxMembers })
            });
        },
        
        showLeaveGangModal() {
            this.showModal = true;
            this.modalType = 'leaveGang';
            this.modalTitle = 'Leave Gang';
            this.modalData = {};
        },
        
        showDisbandGangModal() {
            this.showModal = true;
            this.modalType = 'disbandGang';
            this.modalTitle = 'Disband Gang';
            this.modalData = {};
        },
        
        // Modal management
        closeModal() {
            this.showModal = false;
            this.modalType = '';
            this.modalTitle = '';
            this.modalData = {};
        },
        
        confirmModal() {
            switch (this.modalType) {
                case 'deposit':
                    fetch('https://cold-gangs/depositGangMoney', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ amount: this.modalData.amount })
                    });
                    break;
                    
                case 'withdraw':
                    fetch('https://cold-gangs/withdrawGangMoney', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ amount: this.modalData.amount })
                    });
                    break;
                    
                case 'transfer':
                    fetch('https://cold-gangs/transferGangMoney', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            targetGangId: this.modalData.targetGangId,
                            amount: this.modalData.amount,
                            reason: this.modalData.reason
                        })
                    });
                    break;
                    
                case 'createBusiness':
                    fetch('https://cold-gangs/createBusiness', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ businessType: this.modalData.businessType })
                    });
                    break;
                    
                case 'upgradeBusiness':
                    fetch('https://cold-gangs/upgradeBusiness', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            businessId: this.modalData.businessId,
                            upgradeType: this.modalData.upgradeType
                        })
                    });
                    break;
                    
                case 'declareWar':
                    fetch('https://cold-gangs/declareWar', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ targetGangId: this.modalData.targetGangId })
                    });
                    break;
                    
                case 'planHeist':
                    fetch('https://cold-gangs/planHeist', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ heistType: this.modalData.heistType })
                    });
                    break;
                    
                case 'createStash':
                    fetch('https://cold-gangs/createStash', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            name: this.modalData.name,
                            minRank: this.modalData.minRank
                        })
                    });
                    break;
                    
                case 'kickMember':
                    fetch('https://cold-gangs/kickMember', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            citizenId: this.modalData.citizenId,
                            reason: this.modalData.reason
                        })
                    });
                    break;
                    
                case 'leaveGang':
                    fetch('https://cold-gangs/leaveGang', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({})
                    });
                    break;
                    
                case 'disbandGang':
                    fetch('https://cold-gangs/disbandGang', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({})
                    });
                    break;
            }
            
            this.closeModal();
        },
        
        // Utility functions
        formatNumber(num) {
            return num ? num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",") : "0";
        },
        
        formatDate(dateString) {
            if (!dateString) return 'Unknown';
            const date = new Date(dateString);
            return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
        },
        
        getRankName(rank) {
            if (!this.config || !this.config.Gangs || !this.config.Gangs.Ranks) return 'Unknown';
            return this.config.Gangs.Ranks[rank] ? this.config.Gangs.Ranks[rank].name : 'Unknown';
        },
        
        hasPermission(perm) {
            if (this.gang.isLeader) return true;
            if (!this.config || !this.config.Gangs || !this.config.Gangs.Ranks) return false;
            
            const rankData = this.config.Gangs.Ranks[this.gang.rank];
            if (!rankData) return false;
            
            const permKey = 'can' + perm.charAt(0).toUpperCase() + perm.slice(1);
            return rankData[permKey] === true;
        }
    }
});

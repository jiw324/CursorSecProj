import fs from 'fs';

interface Employee {
    id: number;
    firstName: string;
    lastName: string;
    email: string;
    phone: string;
    address: Address;
    department: string;
    position: string;
    salary: number;
    startDate: Date;
    endDate?: Date;
    manager?: number;
    isManager: boolean;
    status: EmployeeStatus;
    emergencyContact: EmergencyContact;
    benefits: EmployeeBenefits;
    performance: EmployeePerformance;
    documents: EmployeeDocument[];
    createdAt: Date;
    updatedAt: Date;
}

interface Address {
    street: string;
    city: string;
    state: string;
    country: string;
    postalCode: string;
}

interface EmergencyContact {
    name: string;
    relationship: string;
    phone: string;
    email?: string;
}

interface EmployeeBenefits {
    healthInsurance: boolean;
    dentalInsurance: boolean;
    visionInsurance: boolean;
    lifeInsurance: boolean;
    retirementPlan: boolean;
    paidTimeOff: number;
    sickLeave: number;
}

interface EmployeePerformance {
    lastReviewDate: Date;
    rating: PerformanceRating;
    goals: PerformanceGoal[];
    reviews: PerformanceReview[];
}

interface PerformanceGoal {
    id: number;
    description: string;
    dueDate: Date;
    status: GoalStatus;
    progress: number;
    comments: string[];
}

interface PerformanceReview {
    id: number;
    reviewerId: number;
    date: Date;
    rating: PerformanceRating;
    strengths: string[];
    improvements: string[];
    comments: string;
    acknowledgement?: {
        date: Date;
        comments?: string;
    };
}

interface EmployeeDocument {
    id: number;
    type: DocumentType;
    title: string;
    fileName: string;
    uploadDate: Date;
    expiryDate?: Date;
    status: DocumentStatus;
}

interface Department {
    id: number;
    name: string;
    description: string;
    managerId: number;
    budget: number;
    location: string;
    employees: number[];
    createdAt: Date;
    updatedAt: Date;
}

interface Project {
    id: number;
    name: string;
    description: string;
    startDate: Date;
    endDate: Date;
    status: ProjectStatus;
    managerId: number;
    budget: number;
    team: ProjectTeamMember[];
    milestones: ProjectMilestone[];
    createdAt: Date;
    updatedAt: Date;
}

interface ProjectTeamMember {
    employeeId: number;
    role: string;
    allocation: number;
    startDate: Date;
    endDate?: Date;
}

interface ProjectMilestone {
    id: number;
    title: string;
    description: string;
    dueDate: Date;
    status: MilestoneStatus;
    deliverables: string[];
}

interface TimeEntry {
    id: number;
    employeeId: number;
    projectId: number;
    date: Date;
    hours: number;
    description: string;
    status: TimeEntryStatus;
    approvedBy?: number;
    approvedAt?: Date;
}

interface LeaveRequest {
    id: number;
    employeeId: number;
    type: LeaveType;
    startDate: Date;
    endDate: Date;
    duration: number;
    reason: string;
    status: LeaveRequestStatus;
    approvedBy?: number;
    approvedAt?: Date;
    comments: string[];
}

type EmployeeStatus = 'active' | 'on_leave' | 'terminated' | 'suspended';
type PerformanceRating = 'exceptional' | 'exceeds_expectations' | 'meets_expectations' | 'needs_improvement' | 'unsatisfactory';
type GoalStatus = 'not_started' | 'in_progress' | 'completed' | 'cancelled';
type DocumentType = 'contract' | 'id' | 'resume' | 'certification' | 'evaluation' | 'other';
type DocumentStatus = 'valid' | 'expired' | 'pending';
type ProjectStatus = 'planned' | 'in_progress' | 'on_hold' | 'completed' | 'cancelled';
type MilestoneStatus = 'pending' | 'in_progress' | 'completed' | 'delayed';
type TimeEntryStatus = 'pending' | 'approved' | 'rejected';
type LeaveType = 'vacation' | 'sick' | 'personal' | 'bereavement' | 'unpaid';
type LeaveRequestStatus = 'pending' | 'approved' | 'rejected' | 'cancelled';

class ValidationError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'ValidationError';
    }
}

class NotFoundError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'NotFoundError';
    }
}

class EmployeeManagementSystem {
    private employees: Map<number, Employee> = new Map();
    private departments: Map<number, Department> = new Map();
    private projects: Map<number, Project> = new Map();
    private timeEntries: Map<number, TimeEntry> = new Map();
    private leaveRequests: Map<number, LeaveRequest> = new Map();

    private nextEmployeeId = 1;
    private nextDepartmentId = 1;
    private nextProjectId = 1;
    private nextTimeEntryId = 1;
    private nextLeaveRequestId = 1;

    constructor() {
        this.seedData();
    }

    private seedData(): void {
        for (let i = 1; i <= 5; i++) {
            this.departments.set(i, {
                id: i,
                name: `Department ${i}`,
                description: `Description for Department ${i}`,
                managerId: i,
                budget: 100000 * i,
                location: `Floor ${i}`,
                employees: [],
                createdAt: new Date(),
                updatedAt: new Date()
            });
        }

        for (let i = 1; i <= 100; i++) {
            const departmentId = ((i - 1) % 5) + 1;
            const isManager = i <= 5;

            const employee: Employee = {
                id: i,
                firstName: `First${i}`,
                lastName: `Last${i}`,
                email: `employee${i}@company.com`,
                phone: `+1-555-${String(i).padStart(4, '0')}`,
                address: {
                    street: `${i} Main St`,
                    city: `City ${i % 10}`,
                    state: `State ${i % 5}`,
                    country: 'USA',
                    postalCode: `${10000 + i}`
                },
                department: `Department ${departmentId}`,
                position: isManager ? 'Manager' : 'Employee',
                salary: isManager ? 100000 + (i * 1000) : 50000 + (i * 500),
                startDate: new Date(2020, 0, i),
                manager: isManager ? undefined : departmentId,
                isManager,
                status: 'active',
                emergencyContact: {
                    name: `Emergency Contact ${i}`,
                    relationship: 'Family',
                    phone: `+1-555-${String(1000 + i).padStart(4, '0')}`
                },
                benefits: {
                    healthInsurance: true,
                    dentalInsurance: true,
                    visionInsurance: true,
                    lifeInsurance: true,
                    retirementPlan: true,
                    paidTimeOff: 20,
                    sickLeave: 10
                },
                performance: {
                    lastReviewDate: new Date(2023, 11, 31),
                    rating: 'meets_expectations',
                    goals: [
                        {
                            id: 1,
                            description: 'Complete project milestones',
                            dueDate: new Date(2024, 5, 30),
                            status: 'in_progress',
                            progress: 50,
                            comments: []
                        }
                    ],
                    reviews: [
                        {
                            id: 1,
                            reviewerId: departmentId,
                            date: new Date(2023, 11, 31),
                            rating: 'meets_expectations',
                            strengths: ['Communication', 'Teamwork'],
                            improvements: ['Technical skills'],
                            comments: 'Good performance overall'
                        }
                    ]
                },
                documents: [
                    {
                        id: 1,
                        type: 'contract',
                        title: 'Employment Contract',
                        fileName: `contract_${i}.pdf`,
                        uploadDate: new Date(2020, 0, i),
                        status: 'valid'
                    }
                ],
                createdAt: new Date(2020, 0, i),
                updatedAt: new Date()
            };

            this.employees.set(i, employee);
            this.departments.get(departmentId)?.employees.push(i);
        }

        for (let i = 1; i <= 20; i++) {
            const departmentId = ((i - 1) % 5) + 1;
            const project: Project = {
                id: i,
                name: `Project ${i}`,
                description: `Description for Project ${i}`,
                startDate: new Date(2024, 0, 1),
                endDate: new Date(2024, 11, 31),
                status: 'in_progress',
                managerId: departmentId,
                budget: 50000 * i,
                team: [
                    {
                        employeeId: departmentId,
                        role: 'Project Manager',
                        allocation: 50,
                        startDate: new Date(2024, 0, 1)
                    },
                    {
                        employeeId: departmentId + 5,
                        role: 'Team Member',
                        allocation: 100,
                        startDate: new Date(2024, 0, 1)
                    }
                ],
                milestones: [
                    {
                        id: 1,
                        title: 'Phase 1',
                        description: 'Complete phase 1',
                        dueDate: new Date(2024, 2, 31),
                        status: 'in_progress',
                        deliverables: ['Documentation', 'Code']
                    }
                ],
                createdAt: new Date(),
                updatedAt: new Date()
            };

            this.projects.set(i, project);
        }

        for (let i = 1; i <= 1000; i++) {
            const employeeId = (i % 100) + 1;
            const projectId = (i % 20) + 1;

            this.timeEntries.set(i, {
                id: i,
                employeeId,
                projectId,
                date: new Date(2024, 0, Math.floor(i / 50) + 1),
                hours: 8,
                description: `Worked on Project ${projectId}`,
                status: 'approved',
                approvedBy: this.employees.get(employeeId)?.manager,
                approvedAt: new Date()
            });
        }

        for (let i = 1; i <= 200; i++) {
            const employeeId = (i % 100) + 1;
            const duration = Math.floor(Math.random() * 5) + 1;

            this.leaveRequests.set(i, {
                id: i,
                employeeId,
                type: ['vacation', 'sick', 'personal'][i % 3] as LeaveType,
                startDate: new Date(2024, Math.floor(i / 20), (i % 20) + 1),
                endDate: new Date(2024, Math.floor(i / 20), (i % 20) + duration + 1),
                duration,
                reason: `Leave request ${i}`,
                status: ['approved', 'pending', 'rejected'][i % 3] as LeaveRequestStatus,
                approvedBy: i % 3 === 0 ? this.employees.get(employeeId)?.manager : undefined,
                approvedAt: i % 3 === 0 ? new Date() : undefined,
                comments: []
            });
        }
    }

    async getEmployee(id: number): Promise<Employee> {
        const employee = this.employees.get(id);
        if (!employee) throw new NotFoundError(`Employee ${id} not found`);
        return employee;
    }

    async createEmployee(data: Omit<Employee, 'id' | 'createdAt' | 'updatedAt'>): Promise<Employee> {
        const id = this.nextEmployeeId++;
        const now = new Date();
        const employee: Employee = {
            ...data,
            id,
            createdAt: now,
            updatedAt: now
        };

        this.employees.set(id, employee);
        return employee;
    }

    async updateEmployee(id: number, updates: Partial<Employee>): Promise<Employee> {
        const employee = await this.getEmployee(id);
        const updatedEmployee = {
            ...employee,
            ...updates,
            id: employee.id,
            updatedAt: new Date()
        };

        this.employees.set(id, updatedEmployee);
        return updatedEmployee;
    }

    async getDepartment(id: number): Promise<Department> {
        const department = this.departments.get(id);
        if (!department) throw new NotFoundError(`Department ${id} not found`);
        return department;
    }

    async getProject(id: number): Promise<Project> {
        const project = this.projects.get(id);
        if (!project) throw new NotFoundError(`Project ${id} not found`);
        return project;
    }

    async createTimeEntry(data: Omit<TimeEntry, 'id'>): Promise<TimeEntry> {
        const id = this.nextTimeEntryId++;
        const timeEntry: TimeEntry = {
            ...data,
            id
        };

        this.timeEntries.set(id, timeEntry);
        return timeEntry;
    }

    async createLeaveRequest(data: Omit<LeaveRequest, 'id'>): Promise<LeaveRequest> {
        const id = this.nextLeaveRequestId++;
        const leaveRequest: LeaveRequest = {
            ...data,
            id
        };

        this.leaveRequests.set(id, leaveRequest);
        return leaveRequest;
    }

    async approveLeaveRequest(id: number, approverId: number): Promise<LeaveRequest> {
        const request = this.leaveRequests.get(id);
        if (!request) throw new NotFoundError(`Leave request ${id} not found`);
        if (request.status !== 'pending') throw new ValidationError(`Leave request ${id} is not pending`);

        const approver = await this.getEmployee(approverId);
        if (!approver.isManager) throw new ValidationError(`Employee ${approverId} is not a manager`);

        const updatedRequest = {
            ...request,
            status: 'approved' as LeaveRequestStatus,
            approvedBy: approverId,
            approvedAt: new Date()
        };

        this.leaveRequests.set(id, updatedRequest);
        return updatedRequest;
    }

    async getDepartmentStats(): Promise<{
        totalDepartments: number;
        employeeDistribution: Record<string, number>;
        totalBudget: number;
        averageBudget: number;
    }> {
        const departments = Array.from(this.departments.values());
        const employeeDistribution: Record<string, number> = {};

        departments.forEach(dept => {
            employeeDistribution[dept.name] = dept.employees.length;
        });

        const totalBudget = departments.reduce((sum, dept) => sum + dept.budget, 0);

        return {
            totalDepartments: departments.length,
            employeeDistribution,
            totalBudget,
            averageBudget: totalBudget / departments.length
        };
    }

    async getProjectStats(): Promise<{
        totalProjects: number;
        statusDistribution: Record<ProjectStatus, number>;
        totalBudget: number;
        averageBudget: number;
    }> {
        const projects = Array.from(this.projects.values());
        const statusDistribution = projects.reduce(
            (acc, project) => {
                acc[project.status]++;
                return acc;
            },
            {
                planned: 0,
                in_progress: 0,
                on_hold: 0,
                completed: 0,
                cancelled: 0
            } as Record<ProjectStatus, number>
        );

        const totalBudget = projects.reduce((sum, project) => sum + project.budget, 0);

        return {
            totalProjects: projects.length,
            statusDistribution,
            totalBudget,
            averageBudget: totalBudget / projects.length
        };
    }

    async getLeaveStats(): Promise<{
        totalRequests: number;
        statusDistribution: Record<LeaveRequestStatus, number>;
        typeDistribution: Record<LeaveType, number>;
        averageDuration: number;
    }> {
        const requests = Array.from(this.leaveRequests.values());
        const statusDistribution = requests.reduce(
            (acc, request) => {
                acc[request.status]++;
                return acc;
            },
            {
                pending: 0,
                approved: 0,
                rejected: 0,
                cancelled: 0
            } as Record<LeaveRequestStatus, number>
        );

        const typeDistribution = requests.reduce(
            (acc, request) => {
                acc[request.type]++;
                return acc;
            },
            {
                vacation: 0,
                sick: 0,
                personal: 0,
                bereavement: 0,
                unpaid: 0
            } as Record<LeaveType, number>
        );

        const totalDuration = requests.reduce((sum, request) => sum + request.duration, 0);

        return {
            totalRequests: requests.length,
            statusDistribution,
            typeDistribution,
            averageDuration: totalDuration / requests.length
        };
    }
}

const ems = new EmployeeManagementSystem();

async function demonstrateUsage(): Promise<void> {
    try {
        const departmentStats = await ems.getDepartmentStats();
        console.log('Department Statistics:', departmentStats);

        const projectStats = await ems.getProjectStats();
        console.log('Project Statistics:', projectStats);

        const leaveStats = await ems.getLeaveStats();
        console.log('Leave Statistics:', leaveStats);

        const employee = await ems.createEmployee({
            firstName: 'John',
            lastName: 'Doe',
            email: 'john.doe@company.com',
            phone: '+1-555-0000',
            address: {
                street: '123 Main St',
                city: 'Anytown',
                state: 'ST',
                country: 'USA',
                postalCode: '12345'
            },
            department: 'Department 1',
            position: 'Software Engineer',
            salary: 75000,
            startDate: new Date(),
            isManager: false,
            status: 'active',
            emergencyContact: {
                name: 'Jane Doe',
                relationship: 'Spouse',
                phone: '+1-555-0001'
            },
            benefits: {
                healthInsurance: true,
                dentalInsurance: true,
                visionInsurance: true,
                lifeInsurance: true,
                retirementPlan: true,
                paidTimeOff: 20,
                sickLeave: 10
            },
            performance: {
                lastReviewDate: new Date(),
                rating: 'meets_expectations',
                goals: [],
                reviews: []
            },
            documents: []
        });
        console.log('New Employee:', employee);

        const leaveRequest = await ems.createLeaveRequest({
            employeeId: employee.id,
            type: 'vacation',
            startDate: new Date(2024, 6, 1),
            endDate: new Date(2024, 6, 5),
            duration: 5,
            reason: 'Summer vacation',
            status: 'pending',
            comments: []
        });
        console.log('New Leave Request:', leaveRequest);

        const approvedRequest = await ems.approveLeaveRequest(leaveRequest.id, 1);
        console.log('Approved Leave Request:', approvedRequest);

    } catch (error) {
        console.error('Error:', error);
    }
}

demonstrateUsage().catch(console.error);

export {
    EmployeeManagementSystem,
    ValidationError,
    NotFoundError
};

export type {
    Employee,
    Department,
    Project,
    TimeEntry,
    LeaveRequest,
    Address,
    EmergencyContact,
    EmployeeBenefits,
    EmployeePerformance,
    PerformanceGoal,
    PerformanceReview,
    EmployeeDocument,
    ProjectTeamMember,
    ProjectMilestone,
    EmployeeStatus,
    PerformanceRating,
    GoalStatus,
    DocumentType,
    DocumentStatus,
    ProjectStatus,
    MilestoneStatus,
    TimeEntryStatus,
    LeaveType,
    LeaveRequestStatus
}; 
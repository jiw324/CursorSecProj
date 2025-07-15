interface Student {
    id: number;
    firstName: string;
    lastName: string;
    email: string;
    phone: string;
    address: Address;
    dateOfBirth: Date;
    gender: string;
    studentId: string;
    enrollmentDate: Date;
    graduationDate?: Date;
    status: StudentStatus;
    program: Program;
    academicRecord: AcademicRecord;
    financialRecord: FinancialRecord;
    documents: StudentDocument[];
    emergencyContact: EmergencyContact;
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

interface Program {
    id: number;
    name: string;
    code: string;
    department: string;
    description: string;
    duration: number;
    totalCredits: number;
    degreeType: DegreeType;
    requirements: ProgramRequirement[];
    courses: number[];
    createdAt: Date;
    updatedAt: Date;
}

interface ProgramRequirement {
    id: number;
    type: RequirementType;
    description: string;
    minimumCredits?: number;
    minimumGPA?: number;
    requiredCourses?: number[];
    electiveCourses?: number[];
}

interface Course {
    id: number;
    code: string;
    name: string;
    description: string;
    department: string;
    credits: number;
    prerequisites: number[];
    corequisites: number[];
    capacity: number;
    instructor: string;
    schedule: CourseSchedule[];
    syllabus: string;
    status: CourseStatus;
    createdAt: Date;
    updatedAt: Date;
}

interface CourseSchedule {
    day: DayOfWeek;
    startTime: string;
    endTime: string;
    location: string;
}

interface AcademicRecord {
    enrollments: CourseEnrollment[];
    gpa: number;
    totalCredits: number;
    academicStanding: AcademicStanding;
    honors: string[];
    warnings: AcademicWarning[];
}

interface CourseEnrollment {
    id: number;
    courseId: number;
    semester: string;
    status: EnrollmentStatus;
    grade?: string;
    attendance: AttendanceRecord[];
    assignments: AssignmentSubmission[];
    midtermGrade?: string;
    finalGrade?: string;
    createdAt: Date;
    updatedAt: Date;
}

interface AttendanceRecord {
    date: Date;
    status: AttendanceStatus;
    notes?: string;
}

interface AssignmentSubmission {
    id: number;
    assignmentId: number;
    submissionDate: Date;
    status: SubmissionStatus;
    grade?: number;
    feedback?: string;
    files?: string[];
}

interface AcademicWarning {
    id: number;
    type: WarningType;
    date: Date;
    reason: string;
    resolution?: string;
    status: WarningStatus;
}

interface FinancialRecord {
    tuition: TuitionInfo;
    scholarships: Scholarship[];
    transactions: FinancialTransaction[];
    balance: number;
    status: FinancialStatus;
}

interface TuitionInfo {
    amount: number;
    perCredit: number;
    dueDate: Date;
    paymentPlan?: PaymentPlan;
}

interface PaymentPlan {
    id: number;
    numberOfInstallments: number;
    installmentAmount: number;
    frequency: PaymentFrequency;
    nextDueDate: Date;
    remainingBalance: number;
}

interface Scholarship {
    id: number;
    name: string;
    amount: number;
    type: ScholarshipType;
    startDate: Date;
    endDate: Date;
    status: ScholarshipStatus;
}

interface FinancialTransaction {
    id: number;
    date: Date;
    type: TransactionType;
    amount: number;
    description: string;
    status: TransactionStatus;
    paymentMethod?: PaymentMethod;
    reference?: string;
}

interface StudentDocument {
    id: number;
    type: DocumentType;
    title: string;
    fileName: string;
    uploadDate: Date;
    expiryDate?: Date;
    status: DocumentStatus;
    notes?: string;
}

type StudentStatus = 'enrolled' | 'graduated' | 'withdrawn' | 'suspended' | 'on_leave';
type DegreeType = 'associate' | 'bachelor' | 'master' | 'doctorate';
type RequirementType = 'core' | 'elective' | 'thesis' | 'internship' | 'gpa';
type CourseStatus = 'active' | 'cancelled' | 'full' | 'archived';
type DayOfWeek = 'monday' | 'tuesday' | 'wednesday' | 'thursday' | 'friday' | 'saturday' | 'sunday';
type EnrollmentStatus = 'enrolled' | 'dropped' | 'withdrawn' | 'completed';
type AttendanceStatus = 'present' | 'absent' | 'late' | 'excused';
type SubmissionStatus = 'submitted' | 'late' | 'missing' | 'graded';
type AcademicStanding = 'good' | 'warning' | 'probation' | 'suspended';
type WarningType = 'academic' | 'attendance' | 'conduct';
type WarningStatus = 'active' | 'resolved' | 'expired';
type FinancialStatus = 'current' | 'past_due' | 'delinquent' | 'paid';
type ScholarshipType = 'merit' | 'need_based' | 'athletic' | 'departmental';
type ScholarshipStatus = 'active' | 'expired' | 'revoked';
type TransactionType = 'payment' | 'refund' | 'charge' | 'adjustment';
type TransactionStatus = 'pending' | 'completed' | 'failed' | 'reversed';
type PaymentMethod = 'cash' | 'credit_card' | 'debit_card' | 'bank_transfer' | 'check';
type PaymentFrequency = 'monthly' | 'quarterly' | 'semester';
type DocumentType = 'transcript' | 'id' | 'visa' | 'health_record' | 'financial' | 'other';
type DocumentStatus = 'valid' | 'expired' | 'pending';

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

class StudentManagementSystem {
    private students: Map<number, Student> = new Map();
    private programs: Map<number, Program> = new Map();
    private courses: Map<number, Course> = new Map();

    private nextStudentId = 1;
    private nextProgramId = 1;
    private nextCourseId = 1;

    constructor() {
        this.seedData();
    }

    private seedData(): void {
        for (let i = 1; i <= 5; i++) {
            this.programs.set(i, {
                id: i,
                name: `Program ${i}`,
                code: `PROG${i}`,
                department: `Department ${i}`,
                description: `Description for Program ${i}`,
                duration: 4,
                totalCredits: 120,
                degreeType: 'bachelor',
                requirements: [
                    {
                        id: 1,
                        type: 'core',
                        description: 'Core courses requirement',
                        minimumCredits: 60,
                        requiredCourses: [1, 2, 3]
                    },
                    {
                        id: 2,
                        type: 'elective',
                        description: 'Elective courses requirement',
                        minimumCredits: 30,
                        electiveCourses: [4, 5]
                    }
                ],
                courses: [1, 2, 3, 4, 5],
                createdAt: new Date(),
                updatedAt: new Date()
            });
        }

        for (let i = 1; i <= 20; i++) {
            this.courses.set(i, {
                id: i,
                code: `COURSE${i}`,
                name: `Course ${i}`,
                description: `Description for Course ${i}`,
                department: `Department ${Math.ceil(i / 4)}`,
                credits: 3,
                prerequisites: i > 1 ? [i - 1] : [],
                corequisites: [],
                capacity: 30,
                instructor: `Instructor ${i}`,
                schedule: [
                    {
                        day: 'monday',
                        startTime: '09:00',
                        endTime: '10:30',
                        location: `Room ${i}`
                    },
                    {
                        day: 'wednesday',
                        startTime: '09:00',
                        endTime: '10:30',
                        location: `Room ${i}`
                    }
                ],
                syllabus: `Syllabus for Course ${i}`,
                status: 'active',
                createdAt: new Date(),
                updatedAt: new Date()
            });
        }

        for (let i = 1; i <= 100; i++) {
            const programId = ((i - 1) % 5) + 1;
            const program = this.programs.get(programId)!;

            this.students.set(i, {
                id: i,
                firstName: `First${i}`,
                lastName: `Last${i}`,
                email: `student${i}@university.edu`,
                phone: `+1-555-${String(i).padStart(4, '0')}`,
                address: {
                    street: `${i} University Ave`,
                    city: `City ${i % 10}`,
                    state: `State ${i % 5}`,
                    country: 'USA',
                    postalCode: `${10000 + i}`
                },
                dateOfBirth: new Date(2000, i % 12, (i % 28) + 1),
                gender: i % 2 === 0 ? 'Male' : 'Female',
                studentId: `STU${String(i).padStart(6, '0')}`,
                enrollmentDate: new Date(2020, 8, 1),
                status: 'enrolled',
                program,
                academicRecord: {
                    enrollments: program.courses.map(courseId => ({
                        id: i * 100 + courseId,
                        courseId,
                        semester: '2023-FALL',
                        status: 'enrolled',
                        attendance: [],
                        assignments: [],
                        createdAt: new Date(),
                        updatedAt: new Date()
                    })),
                    gpa: 3.0 + (Math.random() * 1.0),
                    totalCredits: 30,
                    academicStanding: 'good',
                    honors: [],
                    warnings: []
                },
                financialRecord: {
                    tuition: {
                        amount: 40000,
                        perCredit: 500,
                        dueDate: new Date(2024, 0, 15)
                    },
                    scholarships: [],
                    transactions: [],
                    balance: 40000,
                    status: 'current'
                },
                documents: [
                    {
                        id: 1,
                        type: 'transcript',
                        title: 'Academic Transcript',
                        fileName: `transcript_${i}.pdf`,
                        uploadDate: new Date(),
                        status: 'valid'
                    }
                ],
                emergencyContact: {
                    name: `Emergency Contact ${i}`,
                    relationship: 'Parent',
                    phone: `+1-555-${String(1000 + i).padStart(4, '0')}`
                },
                createdAt: new Date(),
                updatedAt: new Date()
            });
        }
    }

    async getStudent(id: number): Promise<Student> {
        const student = this.students.get(id);
        if (!student) throw new NotFoundError(`Student ${id} not found`);
        return student;
    }

    async createStudent(data: Omit<Student, 'id' | 'createdAt' | 'updatedAt'>): Promise<Student> {
        const id = this.nextStudentId++;
        const now = new Date();
        const student: Student = {
            ...data,
            id,
            createdAt: now,
            updatedAt: now
        };

        this.students.set(id, student);
        return student;
    }

    async updateStudent(id: number, updates: Partial<Student>): Promise<Student> {
        const student = await this.getStudent(id);
        const updatedStudent = {
            ...student,
            ...updates,
            id: student.id,
            updatedAt: new Date()
        };

        this.students.set(id, updatedStudent);
        return updatedStudent;
    }

    async getCourse(id: number): Promise<Course> {
        const course = this.courses.get(id);
        if (!course) throw new NotFoundError(`Course ${id} not found`);
        return course;
    }

    async enrollStudent(studentId: number, courseId: number, semester: string): Promise<CourseEnrollment> {
        const student = await this.getStudent(studentId);
        const course = await this.getCourse(courseId);

        const completedCourses = student.academicRecord.enrollments
            .filter(e => e.status === 'completed')
            .map(e => e.courseId);

        const missingPrerequisites = course.prerequisites.filter(
            prereqId => !completedCourses.includes(prereqId)
        );

        if (missingPrerequisites.length > 0) {
            throw new ValidationError(
                `Missing prerequisites: ${missingPrerequisites.join(', ')}`
            );
        }

        const currentEnrollments = Array.from(this.students.values())
            .flatMap(s => s.academicRecord.enrollments)
            .filter(e => e.courseId === courseId && e.semester === semester && e.status === 'enrolled')
            .length;

        if (currentEnrollments >= course.capacity) {
            throw new ValidationError(`Course ${courseId} is full`);
        }

        const enrollment: CourseEnrollment = {
            id: Date.now(),
            courseId,
            semester,
            status: 'enrolled',
            attendance: [],
            assignments: [],
            createdAt: new Date(),
            updatedAt: new Date()
        };

        student.academicRecord.enrollments.push(enrollment);
        await this.updateStudent(studentId, student);

        return enrollment;
    }

    async updateGrades(studentId: number, courseId: number, grades: {
        midterm?: string;
        final?: string;
    }): Promise<CourseEnrollment> {
        const student = await this.getStudent(studentId);
        const enrollment = student.academicRecord.enrollments.find(
            e => e.courseId === courseId && e.status === 'enrolled'
        );

        if (!enrollment) {
            throw new NotFoundError(
                `No active enrollment found for student ${studentId} in course ${courseId}`
            );
        }

        const updatedEnrollment = {
            ...enrollment,
            midtermGrade: grades.midterm || enrollment.midtermGrade,
            finalGrade: grades.final || enrollment.finalGrade,
            updatedAt: new Date()
        };

        student.academicRecord.enrollments = student.academicRecord.enrollments.map(
            e => e.id === enrollment.id ? updatedEnrollment : e
        );

        await this.updateStudent(studentId, student);
        return updatedEnrollment;
    }

    async recordPayment(studentId: number, amount: number, method: PaymentMethod): Promise<FinancialTransaction> {
        const student = await this.getStudent(studentId);

        const transaction: FinancialTransaction = {
            id: Date.now(),
            date: new Date(),
            type: 'payment',
            amount,
            description: `Tuition payment`,
            status: 'completed',
            paymentMethod: method,
            reference: `PAY-${Date.now()}`
        };

        student.financialRecord.transactions.push(transaction);
        student.financialRecord.balance -= amount;
        student.financialRecord.status = student.financialRecord.balance <= 0 ? 'paid' : 'current';

        await this.updateStudent(studentId, student);
        return transaction;
    }

    async getEnrollmentStats(): Promise<{
        totalStudents: number;
        studentsPerProgram: Record<string, number>;
        averageGPA: number;
        academicStandingDistribution: Record<AcademicStanding, number>;
    }> {
        const students = Array.from(this.students.values());
        const studentsPerProgram: Record<string, number> = {};

        students.forEach(student => {
            studentsPerProgram[student.program.name] =
                (studentsPerProgram[student.program.name] || 0) + 1;
        });

        const academicStandingDistribution = students.reduce(
            (acc, student) => {
                acc[student.academicRecord.academicStanding]++;
                return acc;
            },
            {
                good: 0,
                warning: 0,
                probation: 0,
                suspended: 0
            } as Record<AcademicStanding, number>
        );

        const totalGPA = students.reduce(
            (sum, student) => sum + student.academicRecord.gpa,
            0
        );

        return {
            totalStudents: students.length,
            studentsPerProgram,
            averageGPA: totalGPA / students.length,
            academicStandingDistribution
        };
    }

    async getCourseStats(): Promise<{
        totalCourses: number;
        coursesPerDepartment: Record<string, number>;
        averageEnrollment: number;
        statusDistribution: Record<CourseStatus, number>;
    }> {
        const courses = Array.from(this.courses.values());
        const coursesPerDepartment: Record<string, number> = {};

        courses.forEach(course => {
            coursesPerDepartment[course.department] =
                (coursesPerDepartment[course.department] || 0) + 1;
        });

        const statusDistribution = courses.reduce(
            (acc, course) => {
                acc[course.status]++;
                return acc;
            },
            {
                active: 0,
                cancelled: 0,
                full: 0,
                archived: 0
            } as Record<CourseStatus, number>
        );

        const totalEnrollments = Array.from(this.students.values())
            .flatMap(s => s.academicRecord.enrollments)
            .filter(e => e.status === 'enrolled')
            .length;

        return {
            totalCourses: courses.length,
            coursesPerDepartment,
            averageEnrollment: totalEnrollments / courses.length,
            statusDistribution
        };
    }

    async getFinancialStats(): Promise<{
        totalRevenue: number;
        outstandingBalance: number;
        paymentMethodDistribution: Record<PaymentMethod, number>;
        statusDistribution: Record<FinancialStatus, number>;
    }> {
        const students = Array.from(this.students.values());

        const paymentMethodDistribution = students
            .flatMap(s => s.financialRecord.transactions)
            .filter(t => t.type === 'payment' && t.paymentMethod)
            .reduce(
                (acc, transaction) => {
                    acc[transaction.paymentMethod!]++;
                    return acc;
                },
                {
                    cash: 0,
                    credit_card: 0,
                    debit_card: 0,
                    bank_transfer: 0,
                    check: 0
                } as Record<PaymentMethod, number>
            );

        const statusDistribution = students.reduce(
            (acc, student) => {
                acc[student.financialRecord.status]++;
                return acc;
            },
            {
                current: 0,
                past_due: 0,
                delinquent: 0,
                paid: 0
            } as Record<FinancialStatus, number>
        );

        const totalRevenue = students
            .flatMap(s => s.financialRecord.transactions)
            .filter(t => t.type === 'payment' && t.status === 'completed')
            .reduce((sum, t) => sum + t.amount, 0);

        const outstandingBalance = students
            .reduce((sum, s) => sum + s.financialRecord.balance, 0);

        return {
            totalRevenue,
            outstandingBalance,
            paymentMethodDistribution,
            statusDistribution
        };
    }
}

const sms = new StudentManagementSystem();

async function demonstrateUsage(): Promise<void> {
    try {
        const enrollmentStats = await sms.getEnrollmentStats();
        console.log('Enrollment Statistics:', enrollmentStats);

        const courseStats = await sms.getCourseStats();
        console.log('Course Statistics:', courseStats);

        const financialStats = await sms.getFinancialStats();
        console.log('Financial Statistics:', financialStats);

        const program: Program = {
            id: 1,
            name: 'Program 1',
            code: 'PROG1',
            department: 'Department 1',
            description: 'Description for Program 1',
            duration: 4,
            totalCredits: 120,
            degreeType: 'bachelor',
            requirements: [
                {
                    id: 1,
                    type: 'core' as RequirementType,
                    description: 'Core courses requirement',
                    minimumCredits: 60,
                    requiredCourses: [1, 2, 3]
                }
            ],
            courses: [1, 2, 3, 4, 5],
            createdAt: new Date(),
            updatedAt: new Date()
        };

        const student = await sms.createStudent({
            firstName: 'John',
            lastName: 'Doe',
            email: 'john.doe@university.edu',
            phone: '+1-555-0000',
            address: {
                street: '123 University St',
                city: 'College Town',
                state: 'ST',
                country: 'USA',
                postalCode: '12345'
            },
            dateOfBirth: new Date(2000, 0, 1),
            gender: 'Male',
            studentId: 'STU000000',
            enrollmentDate: new Date(),
            status: 'enrolled',
            program,
            academicRecord: {
                enrollments: [],
                gpa: 0.0,
                totalCredits: 0,
                academicStanding: 'good',
                honors: [],
                warnings: []
            },
            financialRecord: {
                tuition: {
                    amount: 40000,
                    perCredit: 500,
                    dueDate: new Date(2024, 0, 15)
                },
                scholarships: [],
                transactions: [],
                balance: 40000,
                status: 'current'
            },
            documents: [],
            emergencyContact: {
                name: 'Jane Doe',
                relationship: 'Parent',
                phone: '+1-555-0001'
            }
        });
        console.log('New Student:', student);

        const enrollment = await sms.enrollStudent(student.id, 1, '2024-SPRING');
        console.log('Course Enrollment:', enrollment);

        const payment = await sms.recordPayment(student.id, 10000, 'credit_card');
        console.log('Payment Transaction:', payment);

        const updatedEnrollment = await sms.updateGrades(student.id, 1, {
            midterm: 'A',
            final: 'A-'
        });
        console.log('Updated Enrollment:', updatedEnrollment);

    } catch (error) {
        console.error('Error:', error);
    }
}

demonstrateUsage().catch(console.error);

export {
    StudentManagementSystem,
    ValidationError,
    NotFoundError
};

export type {
    Student,
    Program,
    Course,
    Address,
    EmergencyContact,
    ProgramRequirement,
    CourseSchedule,
    AcademicRecord,
    CourseEnrollment,
    AttendanceRecord,
    AssignmentSubmission,
    AcademicWarning,
    FinancialRecord,
    TuitionInfo,
    PaymentPlan,
    Scholarship,
    FinancialTransaction,
    StudentDocument,
    StudentStatus,
    DegreeType,
    RequirementType,
    CourseStatus,
    DayOfWeek,
    EnrollmentStatus,
    AttendanceStatus,
    SubmissionStatus,
    AcademicStanding,
    WarningType,
    WarningStatus,
    FinancialStatus,
    ScholarshipType,
    ScholarshipStatus,
    TransactionType,
    TransactionStatus,
    PaymentMethod,
    PaymentFrequency,
    DocumentType,
    DocumentStatus
}; 
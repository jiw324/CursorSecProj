interface Book {
    id: number;
    isbn: string;
    title: string;
    subtitle?: string;
    authors: string[];
    publisher: string;
    publishedDate: Date;
    edition?: string;
    description: string;
    pageCount: number;
    categories: string[];
    language: string;
    format: BookFormat;
    location: string;
    status: BookStatus;
    condition: BookCondition;
    acquisitionDate: Date;
    acquisitionPrice: number;
    replacementCost: number;
    notes?: string;
    createdAt: Date;
    updatedAt: Date;
}

interface Member {
    id: number;
    firstName: string;
    lastName: string;
    email: string;
    phone: string;
    address: Address;
    membershipNumber: string;
    membershipType: MembershipType;
    membershipStartDate: Date;
    membershipEndDate: Date;
    status: MemberStatus;
    borrowingPrivileges: BorrowingPrivileges;
    fines: number;
    notes?: string;
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

interface BorrowingPrivileges {
    maxBooks: number;
    maxDays: number;
    maxRenewals: number;
    canReserve: boolean;
    canBorrowReferenceBooks: boolean;
}

interface Loan {
    id: number;
    bookId: number;
    memberId: number;
    loanDate: Date;
    dueDate: Date;
    returnDate?: Date;
    renewalCount: number;
    status: LoanStatus;
    fines?: number;
    notes?: string;
    createdAt: Date;
    updatedAt: Date;
}

interface Reservation {
    id: number;
    bookId: number;
    memberId: number;
    reservationDate: Date;
    expiryDate: Date;
    status: ReservationStatus;
    notificationSent: boolean;
    notes?: string;
    createdAt: Date;
    updatedAt: Date;
}

interface Fine {
    id: number;
    memberId: number;
    loanId: number;
    amount: number;
    reason: string;
    issueDate: Date;
    dueDate: Date;
    paidDate?: Date;
    status: FineStatus;
    paymentMethod?: PaymentMethod;
    notes?: string;
    createdAt: Date;
    updatedAt: Date;
}

type BookFormat = 'hardcover' | 'paperback' | 'ebook' | 'audiobook';
type BookStatus = 'available' | 'loaned' | 'reserved' | 'processing' | 'lost' | 'damaged';
type BookCondition = 'new' | 'good' | 'fair' | 'poor' | 'damaged';
type MembershipType = 'standard' | 'premium' | 'student' | 'senior' | 'corporate';
type MemberStatus = 'active' | 'expired' | 'suspended' | 'cancelled';
type LoanStatus = 'active' | 'overdue' | 'returned' | 'lost';
type ReservationStatus = 'pending' | 'ready' | 'expired' | 'cancelled';
type FineStatus = 'pending' | 'paid' | 'waived';
type PaymentMethod = 'cash' | 'credit_card' | 'debit_card' | 'bank_transfer';

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

class LibraryManagementSystem {
    private books: Map<number, Book> = new Map();
    private members: Map<number, Member> = new Map();
    private loans: Map<number, Loan> = new Map();
    private reservations: Map<number, Reservation> = new Map();
    private fines: Map<number, Fine> = new Map();

    private nextBookId = 1;
    private nextMemberId = 1;
    private nextLoanId = 1;
    private nextReservationId = 1;
    private nextFineId = 1;

    constructor() {
        this.seedData();
    }

    private seedData(): void {
        for (let i = 1; i <= 100; i++) {
            this.books.set(i, {
                id: i,
                isbn: `978-0-${String(i).padStart(4, '0')}-${String(i).padStart(4, '0')}-${i % 10}`,
                title: `Book ${i}`,
                authors: [`Author ${i}`, `Co-author ${i}`],
                publisher: `Publisher ${i % 10}`,
                publishedDate: new Date(2020, i % 12, (i % 28) + 1),
                description: `Description for Book ${i}`,
                pageCount: 200 + (i * 10),
                categories: [`Category ${i % 5}`, `Category ${(i + 1) % 5}`],
                language: 'English',
                format: ['hardcover', 'paperback', 'ebook', 'audiobook'][i % 4] as BookFormat,
                location: `Section ${Math.floor(i / 20)}-Shelf ${i % 20}`,
                status: 'available',
                condition: 'good',
                acquisitionDate: new Date(2020, 0, i),
                acquisitionPrice: 20.00 + (i % 10) * 5,
                replacementCost: 30.00 + (i % 10) * 5,
                createdAt: new Date(),
                updatedAt: new Date()
            });
        }

        for (let i = 1; i <= 50; i++) {
            this.members.set(i, {
                id: i,
                firstName: `First${i}`,
                lastName: `Last${i}`,
                email: `member${i}@library.com`,
                phone: `+1-555-${String(i).padStart(4, '0')}`,
                address: {
                    street: `${i} Library St`,
                    city: `City ${i % 10}`,
                    state: `State ${i % 5}`,
                    country: 'USA',
                    postalCode: `${10000 + i}`
                },
                membershipNumber: `MEM${String(i).padStart(6, '0')}`,
                membershipType: ['standard', 'premium', 'student', 'senior', 'corporate'][i % 5] as MembershipType,
                membershipStartDate: new Date(2020, 0, 1),
                membershipEndDate: new Date(2024, 11, 31),
                status: 'active',
                borrowingPrivileges: {
                    maxBooks: 5,
                    maxDays: 14,
                    maxRenewals: 2,
                    canReserve: true,
                    canBorrowReferenceBooks: false
                },
                fines: 0,
                createdAt: new Date(),
                updatedAt: new Date()
            });
        }

        for (let i = 1; i <= 200; i++) {
            const memberId = (i % 50) + 1;
            const bookId = (i % 100) + 1;
            const loanDate = new Date(2023, 11, i % 28 + 1);
            const dueDate = new Date(loanDate);
            dueDate.setDate(dueDate.getDate() + 14);

            this.loans.set(i, {
                id: i,
                bookId,
                memberId,
                loanDate,
                dueDate,
                returnDate: i % 3 === 0 ? new Date() : undefined,
                renewalCount: i % 2,
                status: ['active', 'overdue', 'returned'][i % 3] as LoanStatus,
                createdAt: new Date(),
                updatedAt: new Date()
            });

            if (this.loans.get(i)?.status === 'active' || this.loans.get(i)?.status === 'overdue') {
                const book = this.books.get(bookId);
                if (book) {
                    book.status = 'loaned';
                }
            }
        }

        for (let i = 1; i <= 50; i++) {
            const memberId = (i % 50) + 1;
            const bookId = (i % 100) + 1;
            const reservationDate = new Date(2024, 0, i % 28 + 1);
            const expiryDate = new Date(reservationDate);
            expiryDate.setDate(expiryDate.getDate() + 7);

            this.reservations.set(i, {
                id: i,
                bookId,
                memberId,
                reservationDate,
                expiryDate,
                status: ['pending', 'ready', 'expired'][i % 3] as ReservationStatus,
                notificationSent: i % 2 === 0,
                createdAt: new Date(),
                updatedAt: new Date()
            });

            if (this.reservations.get(i)?.status === 'pending' || this.reservations.get(i)?.status === 'ready') {
                const book = this.books.get(bookId);
                if (book) {
                    book.status = 'reserved';
                }
            }
        }

        for (let i = 1; i <= 30; i++) {
            const memberId = (i % 50) + 1;
            const loanId = (i % 200) + 1;
            const issueDate = new Date(2024, 0, i % 28 + 1);
            const dueDate = new Date(issueDate);
            dueDate.setDate(dueDate.getDate() + 14);

            this.fines.set(i, {
                id: i,
                memberId,
                loanId,
                amount: (i % 5 + 1) * 5.00,
                reason: 'Late return',
                issueDate,
                dueDate,
                paidDate: i % 3 === 0 ? new Date() : undefined,
                status: ['pending', 'paid', 'waived'][i % 3] as FineStatus,
                paymentMethod: i % 3 === 0 ? ['cash', 'credit_card', 'debit_card'][i % 3] as PaymentMethod : undefined,
                createdAt: new Date(),
                updatedAt: new Date()
            });

            const member = this.members.get(memberId);
            if (member && this.fines.get(i)?.status === 'pending') {
                member.fines += this.fines.get(i)?.amount || 0;
            }
        }
    }

    async getBook(id: number): Promise<Book> {
        const book = this.books.get(id);
        if (!book) throw new NotFoundError(`Book ${id} not found`);
        return book;
    }

    async findBooks(query: Partial<Book>): Promise<Book[]> {
        return Array.from(this.books.values()).filter(book =>
            Object.entries(query).every(([key, value]) => book[key as keyof Book] === value)
        );
    }

    async getMember(id: number): Promise<Member> {
        const member = this.members.get(id);
        if (!member) throw new NotFoundError(`Member ${id} not found`);
        return member;
    }

    async createLoan(memberId: number, bookId: number): Promise<Loan> {
        const member = await this.getMember(memberId);
        const book = await this.getBook(bookId);

        if (member.status !== 'active') {
            throw new ValidationError(`Member ${memberId} is not active`);
        }

        if (member.fines > 0) {
            throw new ValidationError(`Member ${memberId} has outstanding fines`);
        }

        const activeLoans = Array.from(this.loans.values()).filter(
            loan => loan.memberId === memberId && (loan.status === 'active' || loan.status === 'overdue')
        );

        if (activeLoans.length >= member.borrowingPrivileges.maxBooks) {
            throw new ValidationError(`Member ${memberId} has reached maximum borrowing limit`);
        }

        if (book.status !== 'available') {
            throw new ValidationError(`Book ${bookId} is not available`);
        }

        const id = this.nextLoanId++;
        const now = new Date();
        const dueDate = new Date(now);
        dueDate.setDate(dueDate.getDate() + member.borrowingPrivileges.maxDays);

        const loan: Loan = {
            id,
            bookId,
            memberId,
            loanDate: now,
            dueDate,
            renewalCount: 0,
            status: 'active',
            createdAt: now,
            updatedAt: now
        };

        this.loans.set(id, loan);
        book.status = 'loaned';
        this.books.set(bookId, book);

        return loan;
    }

    async returnBook(loanId: number): Promise<Loan> {
        const loan = this.loans.get(loanId);
        if (!loan) throw new NotFoundError(`Loan ${loanId} not found`);
        if (loan.status === 'returned') throw new ValidationError(`Book already returned`);

        const now = new Date();
        const book = await this.getBook(loan.bookId);
        const member = await this.getMember(loan.memberId);

        if (now > loan.dueDate) {
            const daysOverdue = Math.ceil((now.getTime() - loan.dueDate.getTime()) / (1000 * 60 * 60 * 24));
            const fineAmount = daysOverdue * 1.00;

            const fine: Fine = {
                id: this.nextFineId++,
                memberId: loan.memberId,
                loanId: loan.id,
                amount: fineAmount,
                reason: 'Late return',
                issueDate: now,
                dueDate: new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000),
                status: 'pending',
                createdAt: now,
                updatedAt: now
            };

            this.fines.set(fine.id, fine);
            member.fines += fineAmount;
            await this.members.set(member.id, member);
        }

        const updatedLoan = {
            ...loan,
            returnDate: now,
            status: 'returned' as LoanStatus,
            updatedAt: now
        };

        this.loans.set(loanId, updatedLoan);
        book.status = 'available';
        this.books.set(book.id, book);

        return updatedLoan;
    }

    async createReservation(memberId: number, bookId: number): Promise<Reservation> {
        const member = await this.getMember(memberId);
        const book = await this.getBook(bookId);

        if (member.status !== 'active') {
            throw new ValidationError(`Member ${memberId} is not active`);
        }

        if (!member.borrowingPrivileges.canReserve) {
            throw new ValidationError(`Member ${memberId} cannot make reservations`);
        }

        const existingReservation = Array.from(this.reservations.values()).find(
            r => r.bookId === bookId && r.memberId === memberId &&
                (r.status === 'pending' || r.status === 'ready')
        );

        if (existingReservation) {
            throw new ValidationError(`Book ${bookId} is already reserved by member ${memberId}`);
        }

        const id = this.nextReservationId++;
        const now = new Date();
        const expiryDate = new Date(now);
        expiryDate.setDate(expiryDate.getDate() + 7);

        const reservation: Reservation = {
            id,
            bookId,
            memberId,
            reservationDate: now,
            expiryDate,
            status: 'pending',
            notificationSent: false,
            createdAt: now,
            updatedAt: now
        };

        this.reservations.set(id, reservation);
        return reservation;
    }

    async payFine(fineId: number, paymentMethod: PaymentMethod): Promise<Fine> {
        const fine = this.fines.get(fineId);
        if (!fine) throw new NotFoundError(`Fine ${fineId} not found`);
        if (fine.status !== 'pending') throw new ValidationError(`Fine ${fineId} is not pending`);

        const now = new Date();
        const member = await this.getMember(fine.memberId);

        const updatedFine = {
            ...fine,
            status: 'paid' as FineStatus,
            paidDate: now,
            paymentMethod,
            updatedAt: now
        };

        this.fines.set(fineId, updatedFine);
        member.fines -= fine.amount;
        this.members.set(member.id, member);

        return updatedFine;
    }

    async getBookStats(): Promise<{
        totalBooks: number;
        statusDistribution: Record<BookStatus, number>;
        formatDistribution: Record<BookFormat, number>;
        categoryDistribution: Record<string, number>;
    }> {
        const books = Array.from(this.books.values());

        const statusDistribution = books.reduce(
            (acc, book) => {
                acc[book.status]++;
                return acc;
            },
            {
                available: 0,
                loaned: 0,
                reserved: 0,
                processing: 0,
                lost: 0,
                damaged: 0
            } as Record<BookStatus, number>
        );

        const formatDistribution = books.reduce(
            (acc, book) => {
                acc[book.format]++;
                return acc;
            },
            {
                hardcover: 0,
                paperback: 0,
                ebook: 0,
                audiobook: 0
            } as Record<BookFormat, number>
        );

        const categoryDistribution: Record<string, number> = {};
        books.forEach(book => {
            book.categories.forEach(category => {
                categoryDistribution[category] = (categoryDistribution[category] || 0) + 1;
            });
        });

        return {
            totalBooks: books.length,
            statusDistribution,
            formatDistribution,
            categoryDistribution
        };
    }

    async getLoanStats(): Promise<{
        totalLoans: number;
        activeLoans: number;
        overdueLoans: number;
        averageLoanDuration: number;
        statusDistribution: Record<LoanStatus, number>;
    }> {
        const loans = Array.from(this.loans.values());
        const now = new Date();

        const statusDistribution = loans.reduce(
            (acc, loan) => {
                acc[loan.status]++;
                return acc;
            },
            {
                active: 0,
                overdue: 0,
                returned: 0,
                lost: 0
            } as Record<LoanStatus, number>
        );

        const completedLoans = loans.filter(loan => loan.returnDate);
        const totalDuration = completedLoans.reduce(
            (sum, loan) => sum + (loan.returnDate!.getTime() - loan.loanDate.getTime()),
            0
        );

        return {
            totalLoans: loans.length,
            activeLoans: loans.filter(loan => loan.status === 'active').length,
            overdueLoans: loans.filter(loan => loan.status === 'active' && loan.dueDate < now).length,
            averageLoanDuration: completedLoans.length > 0 ? totalDuration / completedLoans.length / (1000 * 60 * 60 * 24) : 0,
            statusDistribution
        };
    }

    async getMemberStats(): Promise<{
        totalMembers: number;
        activeMembers: number;
        totalFines: number;
        membershipDistribution: Record<MembershipType, number>;
        statusDistribution: Record<MemberStatus, number>;
    }> {
        const members = Array.from(this.members.values());

        const membershipDistribution = members.reduce(
            (acc, member) => {
                acc[member.membershipType]++;
                return acc;
            },
            {
                standard: 0,
                premium: 0,
                student: 0,
                senior: 0,
                corporate: 0
            } as Record<MembershipType, number>
        );

        const statusDistribution = members.reduce(
            (acc, member) => {
                acc[member.status]++;
                return acc;
            },
            {
                active: 0,
                expired: 0,
                suspended: 0,
                cancelled: 0
            } as Record<MemberStatus, number>
        );

        return {
            totalMembers: members.length,
            activeMembers: members.filter(m => m.status === 'active').length,
            totalFines: members.reduce((sum, m) => sum + m.fines, 0),
            membershipDistribution,
            statusDistribution
        };
    }
}

const lms = new LibraryManagementSystem();

async function demonstrateUsage(): Promise<void> {
    try {
        const bookStats = await lms.getBookStats();
        console.log('Book Statistics:', bookStats);

        const loanStats = await lms.getLoanStats();
        console.log('Loan Statistics:', loanStats);

        const memberStats = await lms.getMemberStats();
        console.log('Member Statistics:', memberStats);

        const loan = await lms.createLoan(1, 1);
        console.log('New Loan:', loan);

        const returnedLoan = await lms.returnBook(loan.id);
        console.log('Returned Loan:', returnedLoan);

        const reservation = await lms.createReservation(1, 2);
        console.log('New Reservation:', reservation);

        const fine = await lms.payFine(1, 'credit_card');
        console.log('Paid Fine:', fine);

    } catch (error) {
        console.error('Error:', error);
    }
}

demonstrateUsage().catch(console.error);

export {
    LibraryManagementSystem,
    ValidationError,
    NotFoundError
};

export type {
    Book,
    Member,
    Loan,
    Reservation,
    Fine,
    Address,
    BorrowingPrivileges,
    BookFormat,
    BookStatus,
    BookCondition,
    MembershipType,
    MemberStatus,
    LoanStatus,
    ReservationStatus,
    FineStatus,
    PaymentMethod
}; 
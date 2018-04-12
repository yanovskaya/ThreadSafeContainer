import Dispatch
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true
/*:
## Thread-safe контейнер для Array<Int>

 **ThreadSafeContainer** - потокобезопасный контейнер для массива Int.
 
 Все свойства и методы для доступа к элементам массива обернуты в методы пользовательской **concurrent queue**.
 
 **Чтение** элементов происходит синхронно и с разных потоков, **запись** - асинхронно с использованием **Dispatch Barrier**, который обеспечивает, чтобы запись была единственной задачей, работающей с массивом в данный момент. Это позволит избежать **race condition**.
 
 **ВАЖНО:** в данном примере контейнер оборачивает только наиболее часто используемые методы для чтения и записи. При желании его можно дополнить другими методами.
 */
final class ThreadSafeContainer {
    
    // MARK: - Private Properties
    
    private let queue = DispatchQueue(label: "ThreadSafeContainerQueue", qos: .utility, attributes: .concurrent)
    private var unsafeArray: [Int]
    
    // MARK: - Initializations
    
    init() {
        unsafeArray = []
    }
    
    init(_ newElements: [Int]) {
        unsafeArray = newElements
    }
    
    // MARK: - Потокобезопасное чтение элементов
    
    var first: Int? {
        var result: Int?
        queue.sync { result = self.unsafeArray.first }
        return result
    }
    
    var last: Int? {
        var result: Int?
        queue.sync { result = self.unsafeArray.last }
        return result
    }
    
    var count: Int {
        var result: Int!
        queue.sync { result = self.unsafeArray.count }
        return result
    }
    
    var isEmpty: Bool {
        var result: Bool!
        queue.sync { result = self.unsafeArray.isEmpty }
        return result
    }
    
    var description: String {
        var result: String!
        queue.sync { result = self.unsafeArray.description }
        return result
    }
    
    func first(where predicate: (Int) -> Bool) -> Int? {
        var result: Int?
        queue.sync { result = self.unsafeArray.first(where: predicate) }
        return result
    }
    
    func filter(_ isIncluded: (Int) -> Bool) -> [Int] {
        var result = [Int]()
        queue.sync { result = self.unsafeArray.filter(isIncluded) }
        return result
    }

    func index(where predicate: (Int) -> Bool) -> Int? {
        var result: Int?
        queue.sync { result = self.unsafeArray.index(where: predicate) }
        return result
    }

    func sorted(by areInIncreasingOrder: (Int, Int) -> Bool) -> [Int] {
        var result = [Int]()
        queue.sync { result = self.unsafeArray.sorted(by: areInIncreasingOrder) }
        return result
    }

    func flatMap<ElementOfResult>(_ transform: (Int) -> ElementOfResult?) -> [ElementOfResult] {
        var result = [ElementOfResult]()
        queue.sync { result = self.unsafeArray.compactMap(transform) }
        return result
    }

    func forEach(_ body: (Int) -> Void) {
        queue.sync { self.unsafeArray.forEach(body) }
    }

    func contains(where predicate: (Int) -> Bool) -> Bool {
        var result: Bool!
        queue.sync { result = self.unsafeArray.contains(where: predicate) }
        return result
    }
    
    func contains(_ element: Int) -> Bool {
        var result = false
        queue.sync { result = self.unsafeArray.contains(element) }
        return result
    }
    
    // MARK: - Потокобезопасная запись элементов
    
    func append( _ element: Int) {
        queue.async(flags: .barrier) {
            self.unsafeArray.append(element)
        }
    }
    
    func append( _ elements: [Int]) {
        queue.async(flags: .barrier) {
            self.unsafeArray += elements
        }
    }
   
    func insert( _ element: Int, at index: Int) {
        queue.async(flags: .barrier) {
            self.unsafeArray.insert(element, at: index)
        }
    }
    
    func remove(at index: Int, completion: ((Int) -> Void)? = nil) {
        queue.async(flags: .barrier) {
            let element = self.unsafeArray.remove(at: index)
            completion?(element)
        }
    }
    
    func remove(where predicate: @escaping (Int) -> Bool, completion: ((Int) -> Void)? = nil) {
        queue.async(flags: .barrier) {
            guard let index = self.unsafeArray.index(where: predicate) else { return }
            let element = self.unsafeArray.remove(at: index)
            completion?(element)
        }
    }
    
    func removeAll(completion: (([Int]) -> Void)? = nil) {
        queue.async(flags: .barrier) {
            let elements = self.unsafeArray
            self.unsafeArray.removeAll()
            completion?(elements)
        }
    }
    
    static func += (left: inout ThreadSafeContainer, right: Int) {
        left.append(right)
    }
    
    static func += (left: inout ThreadSafeContainer, right: [Int]) {
        left.append(right)
    }
    
    subscript(index: Int) -> Int? {
        get {
            var result: Int?
            queue.sync {
                guard self.unsafeArray.startIndex..<self.unsafeArray.endIndex ~= index else { return }
                result = self.unsafeArray[index]
            }
            return result
        } set {
            guard let newValue = newValue else { return }
            queue.async(flags: .barrier) {
                self.unsafeArray[index] = newValue
            }
        }
    }
}
/*:
 ## Пример использования потокобезопасного контейнера
 */
// Инициализация контейнера
var safeArray = ThreadSafeContainer([1, 2, 3])

// Чтение элементов
safeArray.count
safeArray.description
safeArray.last

// Запись элементов
safeArray.append(4)
safeArray.remove(at: 3)
safeArray.removeAll()

// Проверка на race condition

func safeReadAndMutate() {
    DispatchQueue.concurrentPerform(iterations: 1000) { _ in
        let last = safeArray.last ?? 0
        safeArray.append(last + 1)
    }
}
safeReadAndMutate()
print("Результат чтения и записи потокобезопасного контейнера, safeArray.count: \(safeArray.count)")

// Проверка на race condition обычного массива

// Код ниже закомментирован, чтобы не вызывать ошибку при компиляции проекта.

//var unsafeArray = [Int]()
//func unsafeReadAndMutate() {
//    DispatchQueue.concurrentPerform(iterations: 1000) { _ in
//        let last = unsafeArray.last ?? 0
//        unsafeArray.append(last + 1)
//    }
//}
//unsafeReadAndMutate()
//print("Результат чтения и записи потокоНЕбезопасного массива, unsafeArray.count: \(unsafeArray.count). Из-за race condition количество элементов скорее всего не равно 1000.")

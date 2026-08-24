import { cacheCipher } from '@/settings/encryptionSetting'
import { isNil } from '@/utils/is'
import type { Encryption, EncryptionParams } from '@/utils/cipher'
import { EncryptionFactory } from '@/utils/cipher'

export interface CreateStorageParams extends EncryptionParams {
  prefixKey: string
  storage: Storage
  hasEncrypt: boolean
  timeout?: Nullable<number>
}
export function createStorage({
  prefixKey = '',
  storage = sessionStorage,
  key = cacheCipher.key,
  iv = cacheCipher.iv,
  timeout = null,
  hasEncrypt = true,
}: Partial<CreateStorageParams> = {}) {
  if (hasEncrypt && [key.length, iv.length].some(item => item !== 16))
    throw new Error('When hasEncrypt is true, the key or iv must be 16 bits!')

  const persistEncryption: Encryption = EncryptionFactory.createAesEncryption({
    key: cacheCipher.key,
    iv: cacheCipher.iv,
  })

  /**
   * Cache class
   * Construction parameters can be passed into sessionStorage, localStorage,
   * @class Cache
   * @example
   */
  const WebStorage = class WebStorage {
    private storage: Storage
    private prefixKey?: string
    private encryption: Encryption
    private hasEncrypt: boolean
    constructor() {
      this.storage = storage
      this.prefixKey = prefixKey
      this.encryption = persistEncryption
      this.hasEncrypt = hasEncrypt
    }

    private getKey(key: string) {
      return `${this.prefixKey}${key}`.toUpperCase()
    }

    /**
     * Set cache
     * @param {string} key
     * @param {*} value
     * @param {*} expire Expiration time in seconds
     * @memberof Cache
     */
    set(key: string, value: any, expire: number | null = timeout) {
      const stringData = JSON.stringify({
        value,
        time: Date.now(),
        expire: !isNil(expire) ? new Date().getTime() + expire * 1000 : null,
      })
      const stringifyValue = this.hasEncrypt ? this.encryption.encrypt(stringData) : stringData
      this.storage.setItem(this.getKey(key), stringifyValue)
    }

    /**
     * Read cache
     * @param {string} key
     * @param {*} def
     * @memberof Cache
     */
    get(key: string, def: any = null): any {
      const val = this.storage.getItem(this.getKey(key))
      if (!val)
        return def

      try {
        const decVal = this.hasEncrypt ? this.encryption.decrypt(val) : val
        const data = JSON.parse(decVal)
        const { value, expire } = data
        if (isNil(expire) || expire >= new Date().getTime())
          return value

        this.remove(key)
      }
      catch (e) {
        return def
      }
    }

    /**
     * Delete cache based on key
     * @param {string} key
     * @memberof Cache
     */
    remove(key: string) {
      this.storage.removeItem(this.getKey(key))
    }

    /**
     * Delete all caches of this instance (only keys with this prefixKey)
     * 注意：不可调用 storage.clear()，否则会误删平台标识等业务 localStorage 数据
     */
    clear(): void {
      const keysToRemove: string[] = []
      for (let i = 0; i < this.storage.length; i++) {
        const key = this.storage.key(i)
        if (key && key.startsWith(this.getKey('')))
          keysToRemove.push(key)
      }
      keysToRemove.forEach(key => this.storage.removeItem(key))
    }
  }
  return new WebStorage()
}
